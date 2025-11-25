#!/bin/bash
###############################################################################
#                    FIX KAFKA CONNECTION - BLACK FRIDAY                      #
#                                                                             #
#  Descrição: Corrige problema de timeout do Kafka Producer                  #
#  Problema: KafkaTimeoutError ao enviar mensagens                           #
#  Causa: Kafka anuncia hostname "kafka" mas host não resolve                #
###############################################################################

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           FIX KAFKA CONNECTION - BLACK FRIDAY                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# ═══════════════════════════════════════════════════════════════════════════
# DIAGNÓSTICO
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🔍 Diagnóstico do Problema...${NC}\n"

echo -e "${YELLOW}1. Verificando containers Kafka:${NC}"
docker ps | grep kafka

echo -e "\n${YELLOW}2. Verificando configuração do Kafka:${NC}"
ADVERTISED_HOST=$(docker exec kafka env | grep KAFKA_ADVERTISED_HOST_NAME)
echo "   $ADVERTISED_HOST"

echo -e "\n${YELLOW}3. Verificando se 'kafka' resolve no host:${NC}"
if grep -q "127.0.0.1.*kafka" /etc/hosts 2>/dev/null; then
    echo -e "   ${GREEN}✅ Entrada 'kafka' encontrada em /etc/hosts${NC}"
else
    echo -e "   ${RED}❌ Entrada 'kafka' NÃO encontrada em /etc/hosts${NC}"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SOLUÇÃO 1: ADICIONAR KAFKA AO /etc/hosts
# ═══════════════════════════════════════════════════════════════════════════

echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    SOLUÇÃO 1: /etc/hosts                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Esta solução adiciona a entrada 'kafka' ao arquivo /etc/hosts${NC}"
echo -e "${CYAN}para que seu sistema resolva 'kafka' como 127.0.0.1${NC}\n"

read -p "Deseja adicionar 'kafka' ao /etc/hosts? (s/N): " resposta

if [[ "$resposta" =~ ^[Ss]$ ]]; then
    echo -e "\n${YELLOW}📝 Adicionando entrada ao /etc/hosts...${NC}"
    
    # Verificar se já existe
    if grep -q "127.0.0.1.*kafka" /etc/hosts 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Entrada já existe em /etc/hosts${NC}"
    else
        # Adicionar entrada
        echo "127.0.0.1 kafka" | sudo tee -a /etc/hosts > /dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Entrada adicionada com sucesso!${NC}"
            echo -e "${CYAN}   Conteúdo adicionado: 127.0.0.1 kafka${NC}"
        else
            echo -e "${RED}❌ Erro ao adicionar entrada${NC}"
            exit 1
        fi
    fi
    
    echo -e "\n${YELLOW}🔍 Verificando /etc/hosts:${NC}"
    grep "kafka" /etc/hosts
    
    echo -e "\n${GREEN}✅ Solução 1 aplicada!${NC}"
    echo -e "${CYAN}   Agora o producer deve funcionar corretamente.${NC}\n"
else
    echo -e "${YELLOW}⏭️  Pulando Solução 1...${NC}\n"
fi

# ═══════════════════════════════════════════════════════════════════════════
# SOLUÇÃO 2: REINICIAR KAFKA MANAGER
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              SOLUÇÃO 2: Kafka Manager RUNNING_PID            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Removendo arquivo RUNNING_PID travado do Kafka Manager...${NC}\n"

read -p "Deseja corrigir o Kafka Manager? (s/N): " resposta2

if [[ "$resposta2" =~ ^[Ss]$ ]]; then
    echo -e "\n${YELLOW}🗑️  Removendo RUNNING_PID...${NC}"
    docker exec kafkamanager rm -f /opt/kafka-manager-2.0.0.2/RUNNING_PID
    
    echo -e "${YELLOW}🔄 Reiniciando Kafka Manager...${NC}"
    docker restart kafkamanager
    
    echo -e "${GREEN}✅ Kafka Manager reiniciado!${NC}"
    echo -e "${CYAN}   Aguarde ~30 segundos e acesse: http://localhost:9000${NC}\n"
else
    echo -e "${YELLOW}⏭️  Pulando Solução 2...${NC}\n"
fi

# ═══════════════════════════════════════════════════════════════════════════
# TESTE DE CONECTIVIDADE
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    TESTE DE CONECTIVIDADE                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

read -p "Deseja testar a conectividade com Kafka? (s/N): " resposta3

if [[ "$resposta3" =~ ^[Ss]$ ]]; then
    echo -e "\n${YELLOW}🧪 Testando conexão com Kafka...${NC}\n"
    
    # Teste 1: Listar tópicos
    echo -e "${CYAN}Teste 1: Listar tópicos${NC}"
    docker exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092
    
    # Teste 2: Descrever tópico black-friday-sales
    echo -e "\n${CYAN}Teste 2: Descrever tópico black-friday-sales${NC}"
    docker exec kafka kafka-topics.sh --describe --topic black-friday-sales --bootstrap-server localhost:9092
    
    echo -e "\n${GREEN}✅ Testes concluídos!${NC}\n"
fi

# ═══════════════════════════════════════════════════════════════════════════
# RESUMO E PRÓXIMOS PASSOS
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    CORREÇÃO CONCLUÍDA! 🎉                    ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}📋 Próximos Passos:${NC}\n"
echo -e "${YELLOW}1️⃣  Ativar ambiente virtual:${NC}"
echo -e "    ${GREEN}source venv/bin/activate${NC}\n"

echo -e "${YELLOW}2️⃣  Executar o producer:${NC}"
echo -e "    ${GREEN}python producer.py${NC}\n"

echo -e "${YELLOW}3️⃣  Em outro terminal, executar o Spark:${NC}"
echo -e "    ${GREEN}./run_spark_streaming.sh${NC}\n"

echo -e "${YELLOW}4️⃣  Monitorar no Mongo Express:${NC}"
echo -e "    ${GREEN}http://localhost:8081${NC}\n"

echo -e "${CYAN}💡 Dica: Se ainda houver timeout, verifique:${NC}"
echo -e "   - Firewall/antivírus bloqueando porta 9092"
echo -e "   - Docker Desktop com recursos suficientes (CPU/RAM)"
echo -e "   - Logs do Kafka: ${GREEN}docker logs kafka${NC}\n"

