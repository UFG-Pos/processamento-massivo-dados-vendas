# 🛍️ Agregador de Vendas em Tempo Real - Black Friday

## 📋 Visão Geral

POC (Proof of Concept) de um sistema de processamento de vendas em tempo real utilizando tecnologias de Big Data. O projeto simula um cenário de Black Friday onde vendas são geradas continuamente, processadas em tempo real e agregadas por categoria em janelas de tempo.

**Stack Tecnológica:**
- **Apache Kafka** - Message broker para ingestão de dados
- **Apache Spark Streaming** - Processamento em tempo real com micro-batches
- **MongoDB** - Armazenamento dos dados agregados
- **Docker** - Orquestração de containers
- **Python** - Geração de dados e processamento

---

## 🏗️ Arquitetura de Big Data

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   Producer      │      │   Apache Kafka  │      │  Spark Streaming│      │    MongoDB      │
│   (Host)        │─────▶│   (Container)   │─────▶│   (Container)   │─────▶│   (Container)   │
│                 │      │                 │      │                 │      │                 │
│ • Faker         │      │ • Topic: black- │      │ • Window: 1min  │      │ • Database:     │
│ • kafka-python  │      │   friday-sales  │      │ • Watermark: 2m │      │   black_friday  │
│ • 2 vendas/seg  │      │ • Partitions: 3 │      │ • GroupBy: cat  │      │ • Collection:   │
│                 │      │ • Zookeeper     │      │ • Aggregations  │      │   faturamento_  │
│                 │      │                 │      │ • Checkpoint    │      │   tempo_real    │
└─────────────────┘      └─────────────────┘      └─────────────────┘      └─────────────────┘
        │                        │                         │                         │
    localhost:9092          kafka:9092              namenode (HDFS)            mongo:27017
                                                    (checkpoint)
```

### Fluxo de Dados Detalhado

1. **Ingestão (Producer)**
   - Gera vendas fake usando biblioteca Faker
   - Serializa em JSON com schema: `{id_pedido, categoria, valor, timestamp}`
   - Envia para Kafka via `localhost:9092` com compressão GZIP

2. **Mensageria (Kafka)**
   - Recebe mensagens no tópico `black-friday-sales`
   - Distribui em 3 partições para paralelismo
   - Zookeeper coordena os brokers e mantém metadados

3. **Processamento (Spark Streaming)**
   - Lê stream do Kafka via `kafka:9092` (rede Docker interna)
   - Parse JSON e conversão de tipos (timestamp string → TimestampType)
   - Agregação por janela de 1 minuto + categoria:
     - `SUM(valor)` → faturamento_total
     - `COUNT(id_pedido)` → volume_vendas
   - Watermark de 2 minutos para lidar com dados atrasados
   - Checkpoint em HDFS (`file:///tmp/spark-checkpoint-black-friday`)

4. **Armazenamento (MongoDB)**
   - Recebe micro-batches via `foreachBatch`
   - Autenticação: `root:root`
   - Armazena documentos com estrutura:
     ```json
     {
       "janela_inicio": ISODate,
       "janela_fim": ISODate,
       "categoria": String,
       "faturamento_total": Double,
       "volume_vendas": Long
     }
     ```

---

## 🔧 Pré-requisitos

- **Docker** e **Docker Compose** instalados
- **Python 3.6+** instalado no host
- **Git** (para clonar o repositório)
- **8GB RAM** recomendado para rodar todos os containers

### Containers Necessários

Os seguintes containers devem estar rodando (via `docker-compose`):
- `kafka` - Apache Kafka broker
- `zookeeper` - Coordenação do Kafka
- `mongo` - MongoDB database
- `jupyter-spark` - Spark 2.4.1 com Scala 2.11
- `namenode` - HDFS para checkpoint do Spark
- `mongo-express` (opcional) - Interface web para MongoDB

---

## 🚀 Setup Rápido

### 1. Subir o Ambiente Docker (https://github.com/fabiogjardim/bigdata_docker)

```bash
cd bigdata_docker
docker-compose up -d

# Verificar containers ativos
docker ps | grep -E "kafka|mongo|jupyter-spark|namenode|zookeeper"
```

### 2. Configurar Ambiente Python (Host)

```bash
# Criar e ativar ambiente virtual
python3 -m venv venv
source venv/bin/activate

# Instalar dependências
pip install -r requirements.txt
```

**Ou use o script automatizado:**

```bash
chmod +x setup_venv.sh
./setup_venv.sh
source venv/bin/activate
```

### 3. Corrigir Conectividade Kafka

O Kafka usa hostname `kafka` internamente. Adicione ao `/etc/hosts`:

```bash
chmod +x fix_kafka_connection.sh
./fix_kafka_connection.sh
```

Ou manualmente:

```bash
echo "127.0.0.1 kafka" | sudo tee -a /etc/hosts
```

### 4. Criar Tópico Kafka

```bash
docker exec -it kafka kafka-topics.sh \
    --create \
    --topic black-friday-sales \
    --bootstrap-server localhost:9092 \
    --partitions 3 \
    --replication-factor 1
```

**Verificar criação:**

```bash
docker exec -it kafka kafka-topics.sh \
    --list \
    --bootstrap-server localhost:9092
```

---

## ▶️ Como Executar

### Terminal 1: Iniciar Producer

```bash
source venv/bin/activate
python producer.py
```

**Saída esperada:**
```
========================================
  KAFKA PRODUCER - BLACK FRIDAY
========================================
Conectado ao Kafka: ['localhost:9092']
Topico: black-friday-sales

Venda enviada: {'id_pedido': 'abc-123', 'categoria': 'Eletronicos', 'valor': 1299.99, ...}
```

### Terminal 2: Iniciar Spark Streaming

```bash
./run_spark_streaming.sh
```

**Saída esperada:**
```
======================================================================
       SPARK STREAMING BLACK FRIDAY - INICIANDO...
======================================================================

>>> SparkSession criada com sucesso!
>>> Conectando ao Kafka: kafka:9092
>>> Topico: black-friday-sales

>>> Configurando escrita no MongoDB: mongodb://root:root@mongo:27017
>>> Database: black_friday
>>> Collection: faturamento_tempo_real

>>> Pipeline de streaming iniciado com sucesso!
>>> Checkpoint: file:///tmp/spark-checkpoint-black-friday
>>> Janela de agregacao: 1 minute

>>> Aguardando dados... (Ctrl+C para parar)

>>> Batch 0 escrito no MongoDB (4 registros)
>>> Batch 1 escrito no MongoDB (4 registros)
```

### Terminal 3: Consultar Dados no MongoDB

**Opção 1: Shell interativo**

```bash
docker exec -it mongo mongo -u root -p root --authenticationDatabase admin
```

Dentro do MongoDB:

```javascript
use black_friday
db.faturamento_tempo_real.find().pretty()
db.faturamento_tempo_real.count()
db.faturamento_tempo_real.find().sort({janela_inicio: -1}).limit(10)
```

**Opção 2: Comando direto**

```bash
docker exec -it mongo mongo -u root -p root --authenticationDatabase admin black_friday \
    --eval "db.faturamento_tempo_real.find().pretty()"
```

**Opção 3: Mongo Express (Interface Web)**

Acesse: http://localhost:8081

---

## 📊 Comandos Úteis

### Monitoramento Kafka

```bash
# Listar tópicos
docker exec -it kafka kafka-topics.sh --list --bootstrap-server localhost:9092

# Descrever tópico
docker exec -it kafka kafka-topics.sh --describe --topic black-friday-sales --bootstrap-server localhost:9092

# Consumir mensagens (debug)
docker exec -it kafka kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic black-friday-sales \
    --from-beginning \
    --max-messages 10
```

### Monitoramento Spark

```bash
# Logs do Spark Streaming
docker logs jupyter-spark --tail 100 -f

# Spark UI (se disponível)
# http://localhost:4040
```

### Consultas MongoDB

```bash
# Contar documentos
docker exec -it mongo mongo -u root -p root --authenticationDatabase admin black_friday \
    --eval "db.faturamento_tempo_real.count()"

# Faturamento total por categoria
docker exec -it mongo mongo -u root -p root --authenticationDatabase admin black_friday \
    --eval "db.faturamento_tempo_real.aggregate([{$group: {_id: '\$categoria', total: {$sum: '\$faturamento_total'}}}])"

# Últimos 5 registros
docker exec -it mongo mongo -u root -p root --authenticationDatabase admin black_friday \
    --eval "db.faturamento_tempo_real.find().sort({janela_inicio: -1}).limit(5).pretty()"
```

### Gerenciamento de Containers

```bash
# Status dos containers
docker ps | grep -E "kafka|mongo|jupyter-spark|namenode|zookeeper"

# Logs de um container específico
docker logs kafka --tail 50 -f

# Reiniciar container
docker restart kafka

# Parar todos os containers
cd bigdata_docker
docker-compose down

# Subir novamente
docker-compose up -d
```

---

## 🛠️ Troubleshooting

### Problema 1: Kafka Timeout Error

**Erro:**
```
KafkaTimeoutError: Batch for TopicPartition(topic='black-friday-sales', partition=0) containing 19 record(s) expired
```

**Causa:** O hostname `kafka` não está resolvendo no host.

**Solução:**
```bash
echo "127.0.0.1 kafka" | sudo tee -a /etc/hosts
```

Ou execute:
```bash
./fix_kafka_connection.sh
```

---

### Problema 2: MongoDB Authentication Error

**Erro:**
```
MongoCommandException: Command failed with error 13 (Unauthorized): 'command insert requires authentication'
```

**Causa:** URI do MongoDB sem credenciais.

**Solução:** Verificar que `spark_processor.py` usa:
```python
MONGO_URI = "mongodb://root:root@mongo:27017"
```

---

### Problema 3: Spark ClassNotFoundException

**Erro:**
```
java.lang.ClassNotFoundException: Failed to find data source: mongodb
```

**Causa:** Versões incompatíveis dos JARs (Spark/Scala).

**Solução:** Verificar que `run_spark_streaming.sh` usa as versões corretas:
```bash
--packages org.apache.spark:spark-sql-kafka-0-10_2.11:2.4.1,org.mongodb.spark:mongo-spark-connector_2.11:2.4.0
```

**Versões do ambiente:**
- Spark: 2.4.1
- Scala: 2.11.12
- Java: 1.8.0_201

---

### Problema 4: Namenode UnknownHostException

**Erro:**
```
java.net.UnknownHostException: namenode
```

**Causa:** Container `namenode` não está rodando.

**Solução:**
```bash
docker ps | grep namenode
# Se não estiver rodando:
cd bigdata_docker
docker-compose up -d namenode
```

---

### Problema 5: Python Syntax Error (Emojis)

**Erro:**
```
SyntaxError: invalid syntax (linha com emoji)
```

**Causa:** Python 3.6 no container Spark tem problemas com emojis Unicode.

**Solução:** O código já foi corrigido para usar apenas ASCII. Se encontrar erros, remova emojis e use `.format()` em vez de f-strings.

---

## 📁 Estrutura do Projeto

```
.
├── bigdata_docker/
│   ├── docker-compose.yml          # Orquestração dos containers
│   └── data/                       # Volumes persistentes
│
├── producer.py                     # Gerador de vendas fake (Kafka Producer)
│   ├── Faker: Gera dados sintéticos
│   ├── kafka-python: Cliente Kafka
│   └── Envia para localhost:9092
│
├── spark_processor.py              # Processador Spark Streaming
│   ├── readStream: Lê do Kafka
│   ├── Agregações por janela de tempo
│   ├── foreachBatch: Escreve no MongoDB
│   └── Checkpoint em HDFS
│
├── run_spark_streaming.sh          # Script de submissão Spark
│   ├── Copia arquivo para container
│   ├── spark-submit com JARs corretos
│   └── Configurações otimizadas
│
├── fix_kafka_connection.sh         # Corrige hostname Kafka
├── setup_venv.sh                   # Setup ambiente virtual
├── comandos_uteis.sh               # Menu interativo com comandos úteis
├── consultas_mongodb.js            # Queries MongoDB prontas
├── requirements.txt                # Dependências Python
├── .gitignore                      # Arquivos ignorados pelo Git
└── README.md                       # Esta documentação

```

### Arquivos Principais

#### `producer.py`
Gerador de vendas sintéticas usando Faker. Configurações:
- **Categorias:** Eletronicos, Livros, Casa, Gamer
- **Valor:** R$ 10,00 a R$ 5.000,00
- **Frequência:** 2 vendas/segundo (configurável)
- **Schema:** `{id_pedido: UUID, categoria: String, valor: Float, timestamp: ISO-8601}`

#### `spark_processor.py`
Processador Spark Structured Streaming. Características:
- **Spark:** 2.4.1 (Scala 2.11)
- **Modo:** Micro-batch com trigger padrão
- **Janela:** 1 minuto (tumbling window)
- **Watermark:** 2 minutos (late data tolerance)
- **Output Mode:** Update (apenas registros modificados)
- **Checkpoint:** HDFS local (`file:///tmp/spark-checkpoint-black-friday`)

#### `run_spark_streaming.sh`
Script automatizado de submissão. Funcionalidades:
- Copia `spark_processor.py` para container
- Baixa JARs automaticamente (Kafka + MongoDB connectors)
- Configura memória (1GB driver + 1GB executor)
- Otimizações: 4 partições de shuffle, schema inference desabilitado

---

## 🎓 Conceitos de Big Data Aplicados

### 1. **Streaming vs Batch Processing**
Este projeto usa **Structured Streaming** (micro-batches), não streaming puro. Cada micro-batch processa dados acumulados em intervalos curtos (~segundos).

### 2. **Windowing e Watermarking**
- **Window (1 min):** Agrupa eventos por janelas de tempo fixas
- **Watermark (2 min):** Tolera dados atrasados até 2 minutos após o fim da janela
- **Tumbling Window:** Janelas não sobrepostas (vs sliding windows)

### 3. **Exactly-Once Semantics**
- **Kafka:** `acks=all` garante que mensagens sejam persistidas
- **Spark:** Checkpoint + idempotência garantem processamento exato uma vez
- **MongoDB:** `foreachBatch` com append mode (pode gerar duplicatas em caso de retry)

### 4. **Particionamento**
- **Kafka:** 3 partições permitem paralelismo no consumo
- **Spark:** Shuffle partitions = 4 (configurável via `spark.sql.shuffle.partitions`)

### 5. **Backpressure**
Spark ajusta automaticamente a taxa de leitura do Kafka baseado na capacidade de processamento.

---

## 🔍 Monitoramento e Observabilidade

### Interfaces Web Disponíveis

| Serviço | URL | Descrição |
|---------|-----|-----------|
| Mongo Express | http://localhost:8081 | Interface web para MongoDB |
| Spark UI | http://localhost:4040 | Monitoramento de jobs Spark (quando ativo) |
| Kafka Manager | http://localhost:9000 | Gerenciamento de tópicos Kafka |

### Métricas Importantes

**Producer:**
- Taxa de envio (msgs/segundo)
- Latência de envio
- Erros de timeout

**Kafka:**
- Lag do consumer (diferença entre offset produzido e consumido)
- Throughput (MB/s)
- Partições balanceadas

**Spark:**
- Tempo de processamento por batch
- Records processados por batch
- Watermark atual vs event time

**MongoDB:**
- Documentos inseridos
- Tamanho da collection
- Índices utilizados

---

## 🧪 Testes e Validação

### Teste 1: Fluxo End-to-End

```bash
# 1. Iniciar producer
python producer.py &
PRODUCER_PID=$!

# 2. Aguardar 30 segundos
sleep 30

# 3. Verificar mensagens no Kafka
docker exec -it kafka kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic black-friday-sales \
    --from-beginning \
    --max-messages 5

# 4. Iniciar Spark (em outro terminal)
./run_spark_streaming.sh

# 5. Aguardar 2 minutos e consultar MongoDB
sleep 120
docker exec -it mongo mongo -u root -p root --authenticationDatabase admin black_friday \
    --eval "db.faturamento_tempo_real.count()"

# 6. Parar producer
kill $PRODUCER_PID
```

### Teste 2: Validação de Agregações

```javascript
// No MongoDB, verificar se agregações estão corretas
use black_friday

// Exemplo: Verificar faturamento de uma janela específica
db.faturamento_tempo_real.find({
  categoria: "Eletronicos",
  janela_inicio: ISODate("2025-11-25T08:30:00.000Z")
})

// Comparar com eventos brutos do Kafka (se disponíveis)
```

---

## 📚 Referências e Recursos

### Documentação Oficial
- [Apache Kafka](https://kafka.apache.org/documentation/)
- [Apache Spark Structured Streaming](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
- [MongoDB Manual](https://docs.mongodb.com/manual/)
- [Spark-Kafka Integration](https://spark.apache.org/docs/latest/structured-streaming-kafka-integration.html)

### Bibliotecas Python
- [kafka-python](https://kafka-python.readthedocs.io/)
- [Faker](https://faker.readthedocs.io/)

### Conceitos de Big Data
- [Lambda Architecture](https://en.wikipedia.org/wiki/Lambda_architecture)
- [Windowing in Stream Processing](https://www.oreilly.com/radar/the-world-beyond-batch-streaming-101/)
- [Exactly-Once Semantics](https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/)

---

## 🤝 Contribuindo

Este é um projeto educacional. Sugestões de melhorias:

1. **Adicionar testes unitários** para producer e processador
2. **Implementar schema registry** (Avro/Protobuf) para evolução de schema
3. **Adicionar alertas** (ex: Prometheus + Grafana)
4. **Implementar deduplicação** no MongoDB (upsert com chave composta)
5. **Adicionar CI/CD** com GitHub Actions
6. **Dockerizar o producer** para rodar em container

---

## 📝 Licença

Este projeto é fornecido "como está" para fins educacionais.

---

## 👨‍💻 Autor

Desenvolvido como POC de processamento de dados em tempo real com tecnologias Big Data.

**Stack:** Kafka + Spark Streaming + MongoDB + Docker + Python

---

## 🎯 Próximos Passos

Após dominar este projeto, considere:

1. **Escalar horizontalmente:** Adicionar mais brokers Kafka e workers Spark
2. **Adicionar camada de serving:** API REST com Flask/FastAPI para consultar agregações
3. **Implementar Lambda Architecture completa:** Adicionar batch layer com Spark Batch
4. **Migrar para cloud:** AWS (MSK + EMR + DocumentDB) ou GCP (Pub/Sub + Dataflow + Firestore)
5. **Adicionar ML:** Detecção de anomalias em vendas usando Spark MLlib

---

**🚀 Happy Streaming!**


