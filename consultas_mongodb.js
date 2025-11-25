// ═══════════════════════════════════════════════════════════════════════════
// CONSULTAS MONGODB - BLACK FRIDAY POC
// ═══════════════════════════════════════════════════════════════════════════
//
// Como usar:
//   docker exec -it mongo mongosh < consultas_mongodb.js
//
// Ou copiar e colar no Mongo Express (http://localhost:8081)
//
// ═══════════════════════════════════════════════════════════════════════════

use black_friday;

print("\n╔══════════════════════════════════════════════════════════════╗");
print("║              CONSULTAS MONGODB - BLACK FRIDAY                ║");
print("╚══════════════════════════════════════════════════════════════╝\n");

// ═══════════════════════════════════════════════════════════════════════════
// 1. ÚLTIMAS 10 JANELAS PROCESSADAS
// ═══════════════════════════════════════════════════════════════════════════

print("📊 1. ÚLTIMAS 10 JANELAS PROCESSADAS\n");

db.faturamento_tempo_real
    .find()
    .sort({ janela_inicio: -1 })
    .limit(10)
    .forEach(doc => {
        print(`Janela: ${doc.janela_inicio} → ${doc.janela_fim}`);
        print(`Categoria: ${doc.categoria}`);
        print(`Faturamento: R$ ${doc.faturamento_total.toFixed(2)}`);
        print(`Volume: ${doc.volume_vendas} vendas`);
        print("─────────────────────────────────────────────────────────────\n");
    });

// ═══════════════════════════════════════════════════════════════════════════
// 2. FATURAMENTO TOTAL POR CATEGORIA (AGREGADO)
// ═══════════════════════════════════════════════════════════════════════════

print("\n💰 2. FATURAMENTO TOTAL POR CATEGORIA\n");

db.faturamento_tempo_real.aggregate([
    {
        $group: {
            _id: "$categoria",
            faturamento_total: { $sum: "$faturamento_total" },
            volume_total: { $sum: "$volume_vendas" },
            ticket_medio: { $avg: { $divide: ["$faturamento_total", "$volume_vendas"] } }
        }
    },
    {
        $sort: { faturamento_total: -1 }
    },
    {
        $project: {
            _id: 0,
            categoria: "$_id",
            faturamento_total: { $round: ["$faturamento_total", 2] },
            volume_total: 1,
            ticket_medio: { $round: ["$ticket_medio", 2] }
        }
    }
]).forEach(doc => {
    print(`Categoria: ${doc.categoria}`);
    print(`  Faturamento Total: R$ ${doc.faturamento_total.toFixed(2)}`);
    print(`  Volume Total: ${doc.volume_total} vendas`);
    print(`  Ticket Médio: R$ ${doc.ticket_medio.toFixed(2)}`);
    print("─────────────────────────────────────────────────────────────\n");
});

// ═══════════════════════════════════════════════════════════════════════════
// 3. TOP 5 JANELAS COM MAIOR FATURAMENTO
// ═══════════════════════════════════════════════════════════════════════════

print("\n🏆 3. TOP 5 JANELAS COM MAIOR FATURAMENTO\n");

db.faturamento_tempo_real
    .find()
    .sort({ faturamento_total: -1 })
    .limit(5)
    .forEach(doc => {
        print(`Janela: ${doc.janela_inicio}`);
        print(`Categoria: ${doc.categoria}`);
        print(`Faturamento: R$ ${doc.faturamento_total.toFixed(2)}`);
        print(`Volume: ${doc.volume_vendas} vendas`);
        print("─────────────────────────────────────────────────────────────\n");
    });

// ═══════════════════════════════════════════════════════════════════════════
// 4. EVOLUÇÃO TEMPORAL DO FATURAMENTO (ÚLTIMAS 20 JANELAS)
// ═══════════════════════════════════════════════════════════════════════════

print("\n📈 4. EVOLUÇÃO TEMPORAL DO FATURAMENTO\n");

db.faturamento_tempo_real.aggregate([
    {
        $sort: { janela_inicio: -1 }
    },
    {
        $limit: 20
    },
    {
        $group: {
            _id: "$janela_inicio",
            faturamento_total: { $sum: "$faturamento_total" },
            volume_total: { $sum: "$volume_vendas" }
        }
    },
    {
        $sort: { _id: 1 }
    },
    {
        $project: {
            _id: 0,
            janela: "$_id",
            faturamento: { $round: ["$faturamento_total", 2] },
            volume: "$volume_total"
        }
    }
]).forEach(doc => {
    print(`${doc.janela} | R$ ${doc.faturamento.toFixed(2).padStart(12)} | ${doc.volume.toString().padStart(4)} vendas`);
});

// ═══════════════════════════════════════════════════════════════════════════
// 5. ESTATÍSTICAS GERAIS
// ═══════════════════════════════════════════════════════════════════════════

print("\n\n📊 5. ESTATÍSTICAS GERAIS\n");

const stats = db.faturamento_tempo_real.aggregate([
    {
        $group: {
            _id: null,
            total_janelas: { $sum: 1 },
            faturamento_total: { $sum: "$faturamento_total" },
            volume_total: { $sum: "$volume_vendas" },
            faturamento_medio_janela: { $avg: "$faturamento_total" },
            volume_medio_janela: { $avg: "$volume_vendas" },
            max_faturamento_janela: { $max: "$faturamento_total" },
            min_faturamento_janela: { $min: "$faturamento_total" }
        }
    }
]).toArray()[0];

if (stats) {
    print(`Total de Janelas Processadas: ${stats.total_janelas}`);
    print(`Faturamento Total: R$ ${stats.faturamento_total.toFixed(2)}`);
    print(`Volume Total de Vendas: ${stats.volume_total}`);
    print(`Faturamento Médio por Janela: R$ ${stats.faturamento_medio_janela.toFixed(2)}`);
    print(`Volume Médio por Janela: ${stats.volume_medio_janela.toFixed(2)} vendas`);
    print(`Maior Faturamento em uma Janela: R$ ${stats.max_faturamento_janela.toFixed(2)}`);
    print(`Menor Faturamento em uma Janela: R$ ${stats.min_faturamento_janela.toFixed(2)}`);
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. DISTRIBUIÇÃO DE VENDAS POR CATEGORIA (%)
// ═══════════════════════════════════════════════════════════════════════════

print("\n\n📊 6. DISTRIBUIÇÃO DE VENDAS POR CATEGORIA (%)\n");

const totalGeral = db.faturamento_tempo_real.aggregate([
    { $group: { _id: null, total: { $sum: "$faturamento_total" } } }
]).toArray()[0].total;

db.faturamento_tempo_real.aggregate([
    {
        $group: {
            _id: "$categoria",
            faturamento: { $sum: "$faturamento_total" }
        }
    },
    {
        $project: {
            categoria: "$_id",
            faturamento: 1,
            percentual: { $multiply: [{ $divide: ["$faturamento", totalGeral] }, 100] }
        }
    },
    {
        $sort: { percentual: -1 }
    }
]).forEach(doc => {
    const barra = "█".repeat(Math.round(doc.percentual / 2));
    print(`${doc.categoria.padEnd(15)} | ${barra} ${doc.percentual.toFixed(2)}%`);
});

print("\n╔══════════════════════════════════════════════════════════════╗");
print("║                    FIM DAS CONSULTAS                         ║");
print("╚══════════════════════════════════════════════════════════════╝\n");

