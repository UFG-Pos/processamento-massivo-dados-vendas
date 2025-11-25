#!/bin/bash
###############################################################################
#                    SCRIPT DE SUBMISSÃO - SPARK STREAMING                   #
#                                                                             #
#  Descrição: Submete o job Spark Streaming no container jupyter-spark       #
#  Uso: ./run_spark_streaming.sh                                             #
###############################################################################

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          SUBMISSÃO SPARK STREAMING - BLACK FRIDAY            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# Verificar se o arquivo existe
if [ ! -f "spark_processor.py" ]; then
    echo -e "${RED}❌ Erro: Arquivo spark_processor.py não encontrado!${NC}"
    exit 1
fi

echo -e "${YELLOW}📋 Configurações:${NC}"
echo -e "   Container: jupyter-spark"
echo -e "   Script: spark_processor.py"
echo -e "   Spark Version: 2.4.1"
echo -e "   Scala Version: 2.11\n"

# Copiar o script para dentro do container
echo -e "${BLUE}📦 Copiando script para o container...${NC}"
docker cp spark_processor.py jupyter-spark:/mnt/notebooks/spark_processor.py

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro ao copiar arquivo para o container!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Arquivo copiado com sucesso!${NC}\n"

# Executar spark-submit dentro do container
echo -e "${BLUE}🚀 Iniciando Spark Streaming...${NC}\n"

docker exec -it jupyter-spark spark-submit \
    --master local[*] \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.11:2.4.1,org.mongodb.spark:mongo-spark-connector_2.11:2.4.0 \
    --conf spark.mongodb.output.uri=mongodb://mongo:27017 \
    --conf spark.mongodb.output.database=black_friday \
    --conf spark.mongodb.output.collection=faturamento_tempo_real \
    --conf spark.streaming.stopGracefullyOnShutdown=true \
    --conf spark.sql.streaming.schemaInference=false \
    --conf spark.sql.shuffle.partitions=4 \
    --driver-memory 1g \
    --executor-memory 1g \
    /mnt/notebooks/spark_processor.py

echo -e "\n${YELLOW}⚠️  Job finalizado ou interrompido${NC}"

