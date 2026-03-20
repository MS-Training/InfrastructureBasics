# Azure Data Storage Cost Analysis

## Scenario: 20,000 Reads/Day on 1.2 GB Data

This document provides a cost comparison between Azure Table Storage, CosmosDB, and Azure SQL Database for a workload of 20,000 reads per day on 1.2 GB of data.

---

## Summary Comparison

| Service | Monthly Cost | Cost Rank |
|---------|--------------|-----------|
| **Table Storage** | **~$0.08** | 🥇 Cheapest |
| **CosmosDB Serverless** | **~$0.45** | 🥈 |
| **Azure SQL Basic** | **~$5.00** | 🥉 |
| **CosmosDB Provisioned** | **~$24.00** | 4th |

---

## Detailed Breakdown

### Azure Table Storage

| Component | Calculation | Monthly Cost |
|-----------|-------------|--------------|
| **Storage** | 1.2 GB × $0.045/GB | $0.054 |
| **Read transactions** | 600K reads × $0.00036/10K | $0.022 |
| **Total** | | **~$0.08** |

> Table Storage charges per 10,000 transactions, not per request. Extremely cheap for read-heavy workloads.

---

### CosmosDB Serverless

| Component | Calculation | Monthly Cost |
|-----------|-------------|--------------|
| **Storage** | 1.2 GB × $0.25/GB | $0.30 |
| **Reads** | 20K/day × 30 days × 1 RU = 600K RUs | |
| **Read cost** | 600K RUs × $0.25/1M | $0.15 |
| **Total** | | **~$0.45** |

---

### CosmosDB Provisioned

| Component | Calculation | Monthly Cost |
|-----------|-------------|--------------|
| **Storage** | 1.2 GB × $0.25/GB | $0.30 |
| **Throughput** | 400 RU/s minimum (way more than needed) | ~$23.40 |
| **Total** | | **~$24.00** |

> You're paying for reserved capacity you don't need. Serverless is better for this workload.

---

### Azure SQL Database

| Tier | Handles 20K reads/day? | Monthly Cost |
|------|------------------------|--------------|
| **Basic (5 DTU)** | ✅ Yes, easily | **~$5.00** |
| **S0 (10 DTU)** | ✅ Yes | ~$15.00 |
| **Serverless** | ✅ Yes | ~$5-15 |

> SQL pricing is capacity-based, not per-query. Basic tier includes 2 GB storage and handles this load easily.

---

## Visual Comparison

```
Monthly Cost (20K reads/day, 1.2 GB):

Table Storage       ▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  $0.08
CosmosDB Serverless ▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░  $0.45
Azure SQL Basic     ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░  $5.00
CosmosDB Provisioned▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  $24.00
                    |----|----|----|----|----|----|
                    $0   $4   $8   $12  $16  $20  $24
```

---

## Annual Cost Projection

| Service | Monthly | Annual |
|---------|---------|--------|
| **Table Storage** | $0.08 | **~$1** |
| **CosmosDB Serverless** | $0.45 | **~$5** |
| **Azure SQL Basic** | $5.00 | **~$60** |
| **CosmosDB Provisioned** | $24.00 | **~$288** |

---

## Feature Comparison

| Feature | Table Storage | CosmosDB | Azure SQL |
|---------|---------------|----------|-----------|
| **Complex queries** | ❌ Limited | ⚠️ SQL-like | ✅ Full SQL |
| **Joins** | ❌ No | ❌ No | ✅ Yes |
| **Indexes** | PartitionKey + RowKey only | ✅ Automatic | ✅ Custom |
| **Transactions** | ⚠️ Batch only (same partition) | ✅ Yes | ✅ Full ACID |
| **Schema** | Flexible | Flexible | Fixed |
| **Global replication** | ⚠️ GRS (read-only) | ✅ Multi-region active | ⚠️ Geo-replica |
| **Latency SLA** | None | < 10ms | None |
| **Private Endpoint** | ✅ Yes | ✅ Yes | ✅ Yes |

---

## Recommendation Matrix

| If You Need... | Best Choice | Monthly Cost |
|----------------|-------------|--------------|
| **Absolute lowest cost** | Table Storage | $0.08 |
| **Simple key-value lookups** | Table Storage | $0.08 |
| **Document/JSON model** | CosmosDB Serverless | $0.45 |
| **Low latency guarantee** | CosmosDB Serverless | $0.45 |
| **Complex queries, joins, reporting** | Azure SQL Basic | $5.00 |
| **Relational data model** | Azure SQL Basic | $5.00 |
| **Familiar SQL syntax** | Azure SQL Basic | $5.00 |

---

## Final Recommendation

For **20,000 reads/day on 1.2 GB**:

| Priority | Recommendation |
|----------|----------------|
| **Cost-first** | **Table Storage** (~$0.08/mo) — 60x cheaper than SQL |
| **Features + low cost** | **CosmosDB Serverless** (~$0.45/mo) — best balance |
| **Need SQL queries** | **Azure SQL Basic** (~$5/mo) — still affordable |

---

## Key Takeaways

1. At this workload level, **Table Storage** is practically free
2. Choose **CosmosDB Serverless** if you need richer features like document model or guaranteed latency
3. Choose **Azure SQL** if you need relational queries, joins, or stored procedures
4. Avoid **CosmosDB Provisioned** for low-traffic workloads—you'd pay $24/month for capacity you don't need

---

## Additional Resources

- [Azure Table Storage Pricing](https://azure.microsoft.com/pricing/details/storage/tables/)
- [CosmosDB Pricing](https://azure.microsoft.com/pricing/details/cosmos-db/)
- [Azure SQL Database Pricing](https://azure.microsoft.com/pricing/details/azure-sql-database/)

---

*Generated: February 5, 2026*
