# CosmosDB vs Azure SQL Cost Comparison

For **1.2 million records**, the answer depends heavily on your **access patterns**, not just record count.

## Quick Cost Comparison

| Factor | CosmosDB | Azure SQL |
|--------|----------|-----------|
| **Pricing model** | RU/s (throughput) or serverless | DTU or vCore |
| **Minimum cost** | ~$24/mo (serverless) or ~$24/mo (400 RU/s provisioned) | ~$5/mo (Basic) or ~$15/mo (S0) |
| **Scales based on** | Read/write operations per second | Compute + storage |
| **Storage cost** | ~$0.25/GB/month | Included in tier (varies) |

## Estimated Storage for 1.2M Records

Assuming ~1KB average per document/row:
- **Data size**: ~1.2 GB
- **CosmosDB storage cost**: ~$0.30/month
- **Azure SQL**: Included in most tiers

## Real Cost Drivers

| Your Workload | Better Choice | Why |
|---------------|---------------|-----|
| **Read-heavy, simple queries** | Azure SQL | Lower baseline cost |
| **High write volume, global distribution** | CosmosDB | Built for this |
| **Unpredictable/spiky traffic** | CosmosDB Serverless | Pay per request |
| **Complex queries, joins, reporting** | Azure SQL | Better query engine |
| **Low traffic (< 1000 requests/day)** | Azure SQL | Much cheaper baseline |
| **Guaranteed low latency globally** | CosmosDB | Single-digit ms SLA |

## Rough Monthly Cost Examples

| Scenario | CosmosDB | Azure SQL |
|----------|----------|-----------|
| **Light usage** (10K reads/day) | ~$25-50 | ~$5-15 |
| **Moderate usage** (100K reads/day) | ~$50-100 | ~$15-50 |
| **Heavy usage** (1M+ reads/day) | ~$200-500+ | ~$50-200 |
| **Very high throughput** | $1000+ | $200-500 |

## When CosmosDB is Worth It

### ✅ Yes, worth the cost if:
- You need **global distribution** with multi-region writes
- You need **guaranteed <10ms latency** at 99th percentile
- You have **unpredictable, spiky workloads** (serverless)
- Your data model fits **document/key-value** patterns
- You need **massive horizontal scale**

### ❌ Probably not worth it if:
- Your app is **single-region**
- You need **complex SQL queries, joins, stored procedures**
- Traffic is **predictable and moderate**
- You're doing **relational data with many tables**
- Budget is tight and **$5-15/mo** matters

## Recommendation for 1.2M Records

| If Your App Is... | Use |
|-------------------|-----|
| A traditional web app with moderate traffic | **Azure SQL** (~$15-50/mo) |
| A globally distributed API with high throughput | **CosmosDB** |
| An IoT or event-driven system with spiky writes | **CosmosDB Serverless** |
| A startup watching every dollar | **Azure SQL Basic/S0** |

## Summary

For **1.2M records with typical usage**, **Azure SQL is likely 2-5x cheaper**. CosmosDB's value comes from scale, global distribution, and guaranteed latency—not small-to-medium workloads.

---

*Generated: February 5, 2026*
