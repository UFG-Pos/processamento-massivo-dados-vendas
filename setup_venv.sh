#!/bin/bash
###############################################################################
#                    SETUP AMBIENTE VIRTUAL - BLACK FRIDAY                   #
#                                                                             #
#  Descrição: Cria ambiente virtual Python isolado e instala dependências    #
#  Uso: ./setup_venv.sh                                                      #
###############################################################################

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         SETUP AMBIENTE VIRTUAL - BLACK FRIDAY POC            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICAÇÕES INICIAIS
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🔍 Verificando pré-requisitos...${NC}\n"

# Verificar se Python 3 está instalado
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 não encontrado!${NC}"
    echo -e "${YELLOW}   Instale Python 3.7+ antes de continuar.${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✅ ${PYTHON_VERSION} encontrado${NC}"

# Verificar se pip está instalado
if ! command -v pip3 &> /dev/null; then
    echo -e "${RED}❌ pip3 não encontrado!${NC}"
    echo -e "${YELLOW}   Instale pip3 antes de continuar.${NC}"
    exit 1
fi

PIP_VERSION=$(pip3 --version | awk '{print $1, $2}')
echo -e "${GREEN}✅ ${PIP_VERSION} encontrado${NC}\n"

# ═══════════════════════════════════════════════════════════════════════════
# CRIAÇÃO DO AMBIENTE VIRTUAL
# ═══════════════════════════════════════════════════════════════════════════

VENV_DIR="venv"

if [ -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}⚠️  Ambiente virtual já existe em ./${VENV_DIR}${NC}"
    read -p "   Deseja recriar? (s/N): " resposta
    
    if [[ "$resposta" =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}🗑️  Removendo ambiente virtual antigo...${NC}"
        rm -rf "$VENV_DIR"
    else
        echo -e "${CYAN}ℹ️  Usando ambiente virtual existente${NC}\n"
        
        # Ativar e atualizar pip
        source "$VENV_DIR/bin/activate"
        echo -e "${BLUE}📦 Atualizando pip...${NC}"
        pip install --upgrade pip > /dev/null 2>&1
        
        # Instalar/atualizar dependências
        echo -e "${BLUE}📦 Instalando/atualizando dependências...${NC}\n"
        pip install -r requirements.txt
        
        echo -e "\n${GREEN}✅ Ambiente virtual atualizado com sucesso!${NC}\n"
        
        # Mostrar instruções
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                    COMO USAR O AMBIENTE                      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
        echo -e "${YELLOW}Para ATIVAR o ambiente virtual:${NC}"
        echo -e "  ${GREEN}source venv/bin/activate${NC}"
        echo -e "  ${CYAN}ou use o atalho:${NC} ${GREEN}source activate_venv.sh${NC}\n"
        echo -e "${YELLOW}Para DESATIVAR:${NC}"
        echo -e "  ${GREEN}deactivate${NC}\n"
        echo -e "${YELLOW}Para executar o producer:${NC}"
        echo -e "  ${GREEN}source venv/bin/activate${NC}"
        echo -e "  ${GREEN}python producer.py${NC}\n"
        
        exit 0
    fi
fi

echo -e "${BLUE}🔨 Criando ambiente virtual em ./${VENV_DIR}...${NC}"
python3 -m venv "$VENV_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro ao criar ambiente virtual!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Ambiente virtual criado com sucesso!${NC}\n"

# ═══════════════════════════════════════════════════════════════════════════
# ATIVAÇÃO E INSTALAÇÃO DE DEPENDÊNCIAS
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}🔄 Ativando ambiente virtual...${NC}"
source "$VENV_DIR/bin/activate"

echo -e "${BLUE}📦 Atualizando pip...${NC}"
pip install --upgrade pip > /dev/null 2>&1

echo -e "${GREEN}✅ pip atualizado${NC}\n"

echo -e "${BLUE}📦 Instalando dependências do requirements.txt...${NC}\n"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

pip install -r requirements.txt

if [ $? -ne 0 ]; then
    echo -e "\n${RED}❌ Erro ao instalar dependências!${NC}"
    exit 1
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICAÇÃO DAS INSTALAÇÕES
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}🔍 Verificando instalações...${NC}\n"

# Verificar kafka-python
if python -c "import kafka" 2>/dev/null; then
    KAFKA_VERSION=$(python -c "import kafka; print(kafka.__version__)")
    echo -e "${GREEN}✅ kafka-python ${KAFKA_VERSION}${NC}"
else
    echo -e "${RED}❌ kafka-python não instalado corretamente${NC}"
fi

# Verificar Faker
if python -c "import faker" 2>/dev/null; then
    FAKER_VERSION=$(python -c "import faker; print(faker.__version__)")
    echo -e "${GREEN}✅ Faker ${FAKER_VERSION}${NC}"
else
    echo -e "${RED}❌ Faker não instalado corretamente${NC}"
fi

# Listar todos os pacotes instalados
echo -e "\n${CYAN}📋 Pacotes instalados:${NC}"
pip list | grep -E "kafka-python|Faker|python-dateutil"

# ═══════════════════════════════════════════════════════════════════════════
# CRIAR SCRIPT DE ATIVAÇÃO RÁPIDA
# ═══════════════════════════════════════════════════════════════════════════

echo -e "\n${BLUE}📝 Criando script de ativação rápida...${NC}"

cat > activate_venv.sh << 'EOF'
#!/bin/bash
# Script de ativação rápida do ambiente virtual

if [ -d "venv" ]; then
    source venv/bin/activate
    echo "✅ Ambiente virtual ativado!"
    echo "📦 Python: $(python --version)"
    echo "📍 Localização: $(which python)"
    echo ""
    echo "💡 Para desativar, use: deactivate"
else
    echo "❌ Ambiente virtual não encontrado!"
    echo "   Execute: ./setup_venv.sh"
fi
EOF

chmod +x activate_venv.sh
echo -e "${GREEN}✅ Script activate_venv.sh criado${NC}\n"

# ═══════════════════════════════════════════════════════════════════════════
# FINALIZAÇÃO
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              AMBIENTE VIRTUAL CONFIGURADO! 🎉                ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    COMO USAR O AMBIENTE                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}1️⃣  Para ATIVAR o ambiente virtual:${NC}"
echo -e "    ${GREEN}source venv/bin/activate${NC}"
echo -e "    ${CYAN}ou use o atalho:${NC} ${GREEN}source activate_venv.sh${NC}\n"

echo -e "${YELLOW}2️⃣  Para DESATIVAR:${NC}"
echo -e "    ${GREEN}deactivate${NC}\n"

echo -e "${YELLOW}3️⃣  Para executar o producer:${NC}"
echo -e "    ${GREEN}source venv/bin/activate${NC}"
echo -e "    ${GREEN}python producer.py${NC}\n"

echo -e "${CYAN}💡 Dica: O ambiente já está ativado neste terminal!${NC}"
echo -e "${CYAN}   Você pode executar o producer diretamente.${NC}\n"

echo -e "${YELLOW}📂 Estrutura criada:${NC}"
echo -e "   ${CYAN}venv/${NC}              - Ambiente virtual Python"
echo -e "   ${CYAN}activate_venv.sh${NC}   - Script de ativação rápida\n"

