#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
================================================================================
              SPARK STREAMING PROCESSOR - BLACK FRIDAY

  Descricao: Processa vendas em tempo real do Kafka e agrega no MongoDB
  Tecnologia: PySpark Structured Streaming
  Versao: 1.0.0
================================================================================
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    from_json, col, window, sum as _sum, count, to_timestamp
)
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType, TimestampType
)

# ===========================================================================
# CONFIGURACOES GLOBAIS
# ===========================================================================

# Kafka (Acesso INTERNO via Docker Network)
KAFKA_BOOTSTRAP_SERVERS = "kafka:9092"
KAFKA_TOPIC = "black-friday-sales"

# MongoDB (Acesso INTERNO via Docker Network)
MONGO_URI = "mongodb://root:root@mongo:27017"
MONGO_DATABASE = "black_friday"
MONGO_COLLECTION = "faturamento_tempo_real"

# Configuracoes de Streaming
CHECKPOINT_LOCATION = "file:///tmp/spark-checkpoint-black-friday"
WINDOW_DURATION = "1 minute"
SLIDE_DURATION = "1 minute"  # Janela tumbling (nao sobreposta)

# ===========================================================================
# SCHEMA DE DADOS
# ===========================================================================

# Schema explicito para evitar inferencia lenta
VENDAS_SCHEMA = StructType([
    StructField("id_pedido", StringType(), False),
    StructField("categoria", StringType(), False),
    StructField("valor", DoubleType(), False),
    StructField("timestamp", StringType(), False)  # Receberemos como string ISO-8601
])

# ===========================================================================
# FUNCOES AUXILIARES
# ===========================================================================

def criar_spark_session():
    """
    Cria e configura a SparkSession otimizada para Streaming.

    Returns:
        SparkSession: Sessao Spark configurada
    """
    spark = SparkSession.builder \
        .appName("BlackFriday-RealTime-Aggregator") \
        .config("spark.streaming.stopGracefullyOnShutdown", "true") \
        .config("spark.sql.streaming.schemaInference", "false") \
        .config("spark.sql.shuffle.partitions", "4") \
        .getOrCreate()

    # Define nivel de log para reduzir verbosidade
    spark.sparkContext.setLogLevel("WARN")

    print(">>> SparkSession criada com sucesso!")
    return spark


def ler_stream_kafka(spark):
    """
    Configura a leitura do stream Kafka.

    Args:
        spark (SparkSession): Sessao Spark

    Returns:
        DataFrame: Stream de dados do Kafka
    """
    print(">>> Conectando ao Kafka: {}".format(KAFKA_BOOTSTRAP_SERVERS))
    print(">>> Topico: {}\n".format(KAFKA_TOPIC))
    
    df_kafka = spark.readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", KAFKA_BOOTSTRAP_SERVERS) \
        .option("subscribe", KAFKA_TOPIC) \
        .option("startingOffsets", "latest") \
        .option("failOnDataLoss", "false") \
        .load()
    
    return df_kafka


def processar_vendas(df_kafka):
    """
    Processa os dados de vendas: parse JSON, conversao de tipos e agregacao.

    Args:
        df_kafka (DataFrame): Stream bruto do Kafka

    Returns:
        DataFrame: Stream processado e agregado
    """
    # 1. Parse do JSON (value do Kafka e binario)
    df_vendas = df_kafka.selectExpr("CAST(value AS STRING) as json_value") \
        .select(from_json(col("json_value"), VENDAS_SCHEMA).alias("data")) \
        .select("data.*")

    # 2. Conversao do timestamp de string para TimestampType
    df_vendas = df_vendas.withColumn(
        "timestamp",
        to_timestamp(col("timestamp"))
    )

    # 3. Agregacao por janela de tempo e categoria
    df_agregado = df_vendas \
        .withWatermark("timestamp", "2 minutes") \
        .groupBy(
            window(col("timestamp"), WINDOW_DURATION, SLIDE_DURATION),
            col("categoria")
        ) \
        .agg(
            _sum("valor").alias("faturamento_total"),
            count("id_pedido").alias("volume_vendas")
        )
    
    # 4. Formatacao final para o MongoDB
    df_final = df_agregado.select(
        col("window.start").alias("janela_inicio"),
        col("window.end").alias("janela_fim"),
        col("categoria"),
        col("faturamento_total"),
        col("volume_vendas")
    )
    
    return df_final


def escrever_batch_mongodb(batch_df, batch_id):
    """
    Funcao auxiliar para escrever cada micro-batch no MongoDB.

    Args:
        batch_df (DataFrame): DataFrame do micro-batch
        batch_id (int): ID do batch
    """
    if batch_df.count() > 0:
        batch_df.write \
            .format("com.mongodb.spark.sql.DefaultSource") \
            .mode("append") \
            .option("uri", MONGO_URI) \
            .option("database", MONGO_DATABASE) \
            .option("collection", MONGO_COLLECTION) \
            .save()
        print(">>> Batch {} escrito no MongoDB ({} registros)".format(batch_id, batch_df.count()))


def escrever_mongodb(df_agregado):
    """
    Configura a escrita no MongoDB em modo streaming usando foreachBatch.

    Args:
        df_agregado (DataFrame): Stream agregado

    Returns:
        StreamingQuery: Query de streaming ativa
    """
    print(">>> Configurando escrita no MongoDB: {}".format(MONGO_URI))
    print(">>> Database: {}".format(MONGO_DATABASE))
    print(">>> Collection: {}\n".format(MONGO_COLLECTION))

    query = df_agregado.writeStream \
        .outputMode("update") \
        .foreachBatch(escrever_batch_mongodb) \
        .option("checkpointLocation", CHECKPOINT_LOCATION) \
        .start()

    return query


# ===========================================================================
# FUNCAO PRINCIPAL
# ===========================================================================

def main():
    """
    Orquestra o pipeline de streaming completo.
    """
    print("=" * 70)
    print("       SPARK STREAMING BLACK FRIDAY - INICIANDO...            ")
    print("=" * 70 + "\n")
    
    # 1. Criar SparkSession
    spark = criar_spark_session()
    
    # 2. Ler stream do Kafka
    df_kafka = ler_stream_kafka(spark)
    
    # 3. Processar e agregar vendas
    df_agregado = processar_vendas(df_kafka)
    
    # 4. Escrever no MongoDB
    query = escrever_mongodb(df_agregado)
    
    print(">>> Pipeline de streaming iniciado com sucesso!")
    print(">>> Checkpoint: {}".format(CHECKPOINT_LOCATION))
    print(">>> Janela de agregacao: {}".format(WINDOW_DURATION))
    print("\n>>> Aguardando dados... (Ctrl+C para parar)\n")
    
    # 5. Aguardar termino (ou interrupcao manual)
    query.awaitTermination()


if __name__ == "__main__":
    main()

