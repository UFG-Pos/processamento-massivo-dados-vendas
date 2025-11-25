#!/bin/bash
###############################################################################
#                        COMANDOS ÚTEIS - BLACK FRIDAY                        #
#                                                                             #
#  Descrição: Coleção de comandos para gerenciar a POC                       #
###############################################################################

# ═══════════════════════════════════════════════════════════════════════════
# KAFKA - GERENCIAMENTO DE TÓPICOS
# ═══════════════════════════════════════════════════════════════════════════

# Criar o tópico black-friday-sales
criar_topico() {
    echo "📢 Criando tópico black-friday-sales..."
    docker exec -it kafka kafka-topics.sh \
        --create \
        --topic black-friday-sales \
        --bootstrap-server localhost:9092 \
        --partitions 3 \
        --replication-factor 1
}

# Listar todos os tópicos
listar_topicos() {
    echo "📋 Listando tópicos Kafka..."
    docker exec -it kafka kafka-topics.sh \
        --list \
        --bootstrap-server localhost:9092
}

# Descrever o tópico (ver partições, réplicas, etc)
descrever_topico() {
    echo "🔍 Descrevendo tópico black-friday-sales..."
    docker exec -it kafka kafka-topics.sh \
        --describe \
        --topic black-friday-sales \
        --bootstrap-server localhost:9092
}

# Consumir mensagens do tópico (para debug)
consumir_mensagens() {
    echo "👀 Consumindo mensagens do tópico..."
    docker exec -it kafka kafka-console-consumer.sh \
        --bootstrap-server localhost:9092 \
        --topic black-friday-sales \
        --from-beginning \
        --max-messages 10
}

# Deletar o tópico (cuidado!)
deletar_topico() {
    echo "⚠️  DELETANDO tópico black-friday-sales..."
    docker exec -it kafka kafka-topics.sh \
        --delete \
        --topic black-friday-sales \
        --bootstrap-server localhost:9092
}

# ═══════════════════════════════════════════════════════════════════════════
# MONGODB - CONSULTAS E GERENCIAMENTO
# ═══════════════════════════════════════════════════════════════════════════

# Consultar dados agregados no MongoDB
consultar_mongodb() {
    echo "💾 Consultando dados no MongoDB..."
    docker exec -it mongo mongosh --eval '
        use black_friday;
        db.faturamento_tempo_real.find().sort({janela_inicio: -1}).limit(10).pretty();
    '
}

# Contar documentos na collection
contar_documentos() {
    echo "🔢 Contando documentos..."
    docker exec -it mongo mongosh --eval '
        use black_friday;
        db.faturamento_tempo_real.countDocuments();
    '
}

# Limpar collection (resetar dados)
limpar_collection() {
    echo "🗑️  LIMPANDO collection faturamento_tempo_real..."
    docker exec -it mongo mongosh --eval '
        use black_friday;
        db.faturamento_tempo_real.deleteMany({});
    '
}

# Agregação: Top 5 categorias por faturamento
top_categorias() {
    echo "🏆 Top 5 categorias por faturamento..."
    docker exec -it mongo mongosh --eval '
        use black_friday;
        db.faturamento_tempo_real.aggregate([
            {$group: {
                _id: "$categoria",
                faturamento_total: {$sum: "$faturamento_total"},
                volume_total: {$sum: "$volume_vendas"}
            }},
            {$sort: {faturamento_total: -1}},
            {$limit: 5}
        ]).forEach(printjson);
    '
}

# ═══════════════════════════════════════════════════════════════════════════
# SPARK - MONITORAMENTO E LOGS
# ═══════════════════════════════════════════════════════════════════════════

# Ver logs do Spark Streaming
ver_logs_spark() {
    echo "📜 Logs do container Spark..."
    docker logs -f jupyter-spark
}

# Limpar checkpoint do Spark (forçar restart limpo)
limpar_checkpoint() {
    echo "🧹 Limpando checkpoint do Spark..."
    docker exec -it jupyter-spark rm -rf /tmp/spark-checkpoint-black-friday
}

# Verificar processos Spark rodando
processos_spark() {
    echo "⚙️  Processos Spark ativos..."
    docker exec -it jupyter-spark jps
}

# ═══════════════════════════════════════════════════════════════════════════
# DOCKER - GERENCIAMENTO DE CONTAINERS
# ═══════════════════════════════════════════════════════════════════════════

# Status dos containers principais
status_containers() {
    echo "🐳 Status dos containers..."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "kafka|mongo|jupyter-spark|zookeeper"
}

# Reiniciar container Kafka
reiniciar_kafka() {
    echo "🔄 Reiniciando Kafka..."
    docker restart kafka
    sleep 5
    echo "✅ Kafka reiniciado!"
}

# Reiniciar container MongoDB
reiniciar_mongo() {
    echo "🔄 Reiniciando MongoDB..."
    docker restart mongo
    sleep 3
    echo "✅ MongoDB reiniciado!"
}

# Reiniciar container Spark
reiniciar_spark() {
    echo "🔄 Reiniciando Spark..."
    docker restart jupyter-spark
    sleep 5
    echo "✅ Spark reiniciado!"
}

# ═══════════════════════════════════════════════════════════════════════════
# MENU INTERATIVO
# ═══════════════════════════════════════════════════════════════════════════

menu() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           COMANDOS ÚTEIS - BLACK FRIDAY POC                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "KAFKA:"
    echo "  1) Criar tópico"
    echo "  2) Listar tópicos"
    echo "  3) Descrever tópico"
    echo "  4) Consumir mensagens (debug)"
    echo "  5) Deletar tópico"
    echo ""
    echo "MONGODB:"
    echo "  6) Consultar dados agregados"
    echo "  7) Contar documentos"
    echo "  8) Top 5 categorias"
    echo "  9) Limpar collection"
    echo ""
    echo "SPARK:"
    echo " 10) Ver logs do Spark"
    echo " 11) Limpar checkpoint"
    echo " 12) Processos Spark ativos"
    echo ""
    echo "DOCKER:"
    echo " 13) Status dos containers"
    echo " 14) Reiniciar Kafka"
    echo " 15) Reiniciar MongoDB"
    echo " 16) Reiniciar Spark"
    echo ""
    echo "  0) Sair"
    echo ""
    read -p "Escolha uma opção: " opcao
    
    case $opcao in
        1) criar_topico ;;
        2) listar_topicos ;;
        3) descrever_topico ;;
        4) consumir_mensagens ;;
        5) deletar_topico ;;
        6) consultar_mongodb ;;
        7) contar_documentos ;;
        8) top_categorias ;;
        9) limpar_collection ;;
        10) ver_logs_spark ;;
        11) limpar_checkpoint ;;
        12) processos_spark ;;
        13) status_containers ;;
        14) reiniciar_kafka ;;
        15) reiniciar_mongo ;;
        16) reiniciar_spark ;;
        0) echo "👋 Até logo!"; exit 0 ;;
        *) echo "❌ Opção inválida!" ;;
    esac
    
    read -p "Pressione ENTER para continuar..."
    menu
}

# Executar menu se o script for chamado diretamente
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    menu
fi

