#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║                    PRODUCER DE VENDAS - BLACK FRIDAY                         ║
║                                                                              ║
║  Descrição: Gera eventos de vendas fake e envia para o Kafka em tempo real  ║
║  Autor: Engenharia de Dados                                                 ║
║  Versão: 1.0.0                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import json
import time
import uuid
from datetime import datetime
from random import uniform, choice
from kafka import KafkaProducer
from kafka.errors import KafkaError

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURAÇÕES GLOBAIS
# ═══════════════════════════════════════════════════════════════════════════

# Configuração do Kafka (HOST - acesso externo)
KAFKA_BOOTSTRAP_SERVERS = ['localhost:9092']
KAFKA_TOPIC = 'black-friday-sales'

# Configuração de Negócio
CATEGORIAS = ['Eletronicos', 'Livros', 'Casa', 'Gamer']
VALOR_MIN = 10.0
VALOR_MAX = 5000.0
INTERVALO_GERACAO = 0.5  # segundos entre cada venda (2 vendas/segundo)

# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÕES AUXILIARES
# ═══════════════════════════════════════════════════════════════════════════

def gerar_venda():
    """
    Gera um evento de venda fake seguindo o schema definido.
    
    Returns:
        dict: Dicionário com os dados da venda
    """
    venda = {
        "id_pedido": str(uuid.uuid4()),
        "categoria": choice(CATEGORIAS),
        "valor": round(uniform(VALOR_MIN, VALOR_MAX), 2),
        "timestamp": datetime.now().isoformat()
    }
    return venda


def criar_producer():
    """
    Cria e configura o produtor Kafka com tratamento de erros.
    
    Returns:
        KafkaProducer: Instância configurada do produtor
    """
    try:
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            # Configurações de confiabilidade
            acks='all',  # Aguarda confirmação de todas as réplicas
            retries=3,   # Tenta reenviar em caso de falha
            # Configurações de performance
            compression_type='gzip',  # Compressão para reduzir tráfego de rede
            linger_ms=10,  # Aguarda 10ms para fazer batch de mensagens
            batch_size=16384  # Tamanho do batch em bytes
        )
        print("✅ Produtor Kafka conectado com sucesso!")
        return producer
    except KafkaError as e:
        print(f"❌ Erro ao conectar no Kafka: {e}")
        raise


def enviar_venda(producer, venda):
    """
    Envia uma venda para o tópico Kafka com callback de confirmação.
    
    Args:
        producer (KafkaProducer): Instância do produtor
        venda (dict): Dados da venda a ser enviada
    """
    def on_send_success(record_metadata):
        print(f"✅ Venda enviada | Tópico: {record_metadata.topic} | "
              f"Partição: {record_metadata.partition} | "
              f"Offset: {record_metadata.offset} | "
              f"Categoria: {venda['categoria']} | "
              f"Valor: R$ {venda['valor']:.2f}")
    
    def on_send_error(excp):
        print(f"❌ Erro ao enviar venda: {excp}")
    
    # Envia de forma assíncrona com callbacks
    producer.send(KAFKA_TOPIC, value=venda).add_callback(
        on_send_success
    ).add_errback(on_send_error)


# ═══════════════════════════════════════════════════════════════════════════
# FUNÇÃO PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════

def main():
    """
    Loop principal de geração e envio de vendas.
    """
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║          PRODUCER BLACK FRIDAY - INICIANDO...                ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print(f"\n📡 Kafka Servers: {KAFKA_BOOTSTRAP_SERVERS}")
    print(f"📢 Tópico: {KAFKA_TOPIC}")
    print(f"🏷️  Categorias: {CATEGORIAS}")
    print(f"💰 Faixa de Valores: R$ {VALOR_MIN:.2f} - R$ {VALOR_MAX:.2f}")
    print(f"⏱️  Intervalo: {INTERVALO_GERACAO}s\n")
    
    # Cria o produtor
    producer = criar_producer()
    
    contador = 0
    
    try:
        print("🚀 Iniciando geração de vendas... (Ctrl+C para parar)\n")
        
        while True:
            # Gera uma venda
            venda = gerar_venda()
            
            # Envia para o Kafka
            enviar_venda(producer, venda)
            
            contador += 1
            
            # Aguarda o intervalo configurado
            time.sleep(INTERVALO_GERACAO)
            
    except KeyboardInterrupt:
        print(f"\n\n⚠️  Interrompido pelo usuário!")
        print(f"📊 Total de vendas geradas: {contador}")
    
    except Exception as e:
        print(f"\n❌ Erro inesperado: {e}")
    
    finally:
        # Garante que todas as mensagens pendentes sejam enviadas
        print("\n🔄 Finalizando produtor...")
        producer.flush()
        producer.close()
        print("✅ Produtor finalizado com sucesso!")


if __name__ == "__main__":
    main()

