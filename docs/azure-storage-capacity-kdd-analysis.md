# Azure Data Storage Capacity Analysis
## KDD (Knowledge Discovery in Databases) Methodology Report

---

## Executive Summary

This document provides a comprehensive analysis of data storage capacities across Azure SQL Database, CosmosDB, and Azure Table Storage using the KDD methodology.

### Key Findings

| Service | Max Storage | Max Item Size | Best For |
|---------|-------------|---------------|----------|
| **Azure SQL** | 100 TB | 2 GB/row | Structured relational data |
| **CosmosDB** | Unlimited | 2 MB/doc | Large-scale document data |
| **Table Storage** | 5 PB | 1 MB/entity | Massive key-value datasets |

---

# Phase 1: Selection

## 1.1 Problem Definition

**Objective**: Analyze and compare the maximum data storage capabilities of Azure's primary database services to guide architectural decisions based on data volume requirements.

## 1.2 Scope

| Parameter | Included |
|-----------|----------|
| Maximum database/account size | ✅ |
| Maximum individual record size | ✅ |
| Maximum number of records | ✅ |
| Partition/distribution limits | ✅ |
| Property/column limits | ✅ |

## 1.3 Data Sources

| Source | Type |
|--------|------|
| Azure SQL Documentation | Official Microsoft docs |
| CosmosDB Service Limits | Official Microsoft docs |
| Azure Storage Limits | Official Microsoft docs |
| Azure Pricing Pages | Service tier specifications |

---

# Phase 2: Preprocessing

## 2.1 Data Standardization

All storage values normalized to consistent units:

| Unit | Conversion |
|------|------------|
| KB (Kilobyte) | 1,024 bytes |
| MB (Megabyte) | 1,024 KB |
| GB (Gigabyte) | 1,024 MB |
| TB (Terabyte) | 1,024 GB |
| PB (Petabyte) | 1,024 TB |

## 2.2 Service Tier Selection

For Azure SQL, multiple tiers exist. Analysis covers all tiers:

| Tier | Max Size | Use Case |
|------|----------|----------|
| Basic | 2 GB | Dev/test |
| Standard | 1 TB | Small-medium production |
| Premium | 4 TB | High-performance |
| Business Critical | 4 TB | Mission-critical |
| Hyperscale | 100 TB | Large-scale enterprise |

---

# Phase 3: Transformation

## 3.1 Azure SQL Database Storage Limits

### Database Size Limits by Tier

| Tier | DTU/vCore | Max Size | Max Databases/Server |
|------|-----------|----------|---------------------|
| Basic | 5 DTU | 2 GB | 500 |
| S0 | 10 DTU | 250 GB | 500 |
| S1 | 20 DTU | 250 GB | 500 |
| S2 | 50 DTU | 250 GB | 500 |
| S3 | 100 DTU | 1 TB | 500 |
| P1 | 125 DTU | 1 TB | 500 |
| P2 | 250 DTU | 1 TB | 500 |
| P4 | 500 DTU | 1 TB | 500 |
| P6 | 1000 DTU | 1 TB | 500 |
| P11 | 1750 DTU | 4 TB | 500 |
| P15 | 4000 DTU | 4 TB | 500 |
| General Purpose | 2-80 vCores | 4 TB | 500 |
| Business Critical | 2-128 vCores | 4 TB | 500 |
| Hyperscale | 2-128 vCores | 100 TB | 500 |

### Row and Column Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Max row size (in-row) | 8,060 bytes | Fixed + variable columns |
| Max row size (with overflow) | 8,060 bytes + 2 GB | Using MAX data types |
| Max columns per table | 1,024 | Hard limit |
| Max bytes per row (all columns) | 8,060 bytes | In-row data |
| Max varchar(MAX) | 2 GB | Stored in LOB pages |
| Max nvarchar(MAX) | 1 GB | 2 bytes per character |
| Max varbinary(MAX) | 2 GB | Binary large object |
| Max XML column | 2 GB | Stored as LOB |

### Object Limits

| Object | Maximum |
|--------|---------|
| Tables per database | 2,147,483,647 |
| Columns per table | 1,024 |
| Indexes per table | 999 |
| Rows per table | Unlimited (storage bound) |
| Bytes per index key | 900 bytes (nonclustered) |
| Foreign keys per table | 253 |
| Stored procedures per database | Unlimited |

---

## 3.2 CosmosDB Storage Limits

### Account and Container Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Max storage per account | Unlimited | No hard cap |
| Max storage per database | Unlimited | No hard cap |
| Max storage per container | Unlimited | No hard cap |
| Max logical partition size | 20 GB | Per partition key value |
| Max physical partition size | 50 GB | Managed by CosmosDB |

### Document Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Max document size | 2 MB | Including all properties |
| Max property name length | 1,024 characters | UTF-8 encoded |
| Max string property value | 2 MB | Per property |
| Max nesting depth | 128 levels | Object/array nesting |
| Max properties per document | No hard limit | Size-bound only |
| Max indexed properties | 500 | Default, configurable |

### Throughput Limits

| Limit | Serverless | Provisioned |
|-------|------------|-------------|
| Max RU/s per container | 5,000 | 1,000,000+ |
| Max RU/s per partition | 10,000 | 10,000 |
| Max operations/second | Varies by RU | Varies by RU |

### Partition Key Considerations

| Limit | Value |
|-------|-------|
| Max partition key size | 2 KB |
| Max logical partition size | 20 GB |
| Recommended partition size | < 10 GB |
| Cross-partition query overhead | High |

---

## 3.3 Azure Table Storage Limits

### Storage Account Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Max storage account size | 5 PB | Per account |
| Max tables per account | Unlimited | No hard cap |
| Max table size | Unlimited | No hard cap |
| Max entities per table | Unlimited | No hard cap |

### Entity Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Max entity size | 1 MB | Including all properties |
| Max properties per entity | 255 | Including system properties |
| Max property name size | 255 characters | Per property |
| Max string property size | 64 KB | Per property |
| Max binary property size | 64 KB | Per property |
| Max DateTime range | Jan 1, 1601 - Dec 31, 9999 | UTC |
| Max Int64 | 9,223,372,036,854,775,807 | Standard long |

### Key Limits

| Limit | Value |
|-------|-------|
| Max PartitionKey size | 1 KB |
| Max RowKey size | 1 KB |
| Combined PartitionKey + RowKey | 2 KB |
| Max PartitionKey + RowKey characters | ~500 each (UTF-16) |

### Transaction Limits

| Limit | Value |
|-------|-------|
| Max batch size | 100 entities |
| Max batch payload | 4 MB |
| Batch scope | Same partition only |

---

# Phase 4: Data Mining

## 4.1 Comparative Analysis

### Maximum Total Storage Capacity

| Service | Maximum | Scale |
|---------|---------|-------|
| Table Storage | 5 PB | Largest |
| CosmosDB | Unlimited* | Theoretically infinite |
| Azure SQL (Hyperscale) | 100 TB | Largest relational |
| Azure SQL (Standard) | 1 TB | Typical production |

*CosmosDB has no stated maximum but practical limits apply based on cost and partition design.

```
Storage Capacity Scale:

Table Storage (5 PB)     ████████████████████████████████████████  5,120 TB
CosmosDB (Unlimited)     ████████████████████████████████████████→ ∞
Azure SQL Hyperscale     ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  100 TB
Azure SQL Premium        ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  4 TB
Azure SQL Standard       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  1 TB
```

### Maximum Individual Record Size

| Service | Max Record | Comparison |
|---------|------------|------------|
| Azure SQL | 2 GB (with LOB) | Largest |
| CosmosDB | 2 MB | Medium |
| Table Storage | 1 MB | Smallest |

```
Individual Record Size:

Azure SQL (2 GB)     ████████████████████████████████████████  2,048 MB
CosmosDB (2 MB)      ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  2 MB
Table Storage (1 MB) ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  1 MB
```

### Properties/Columns per Record

| Service | Max Properties | Flexibility |
|---------|----------------|-------------|
| Azure SQL | 1,024 columns | Fixed schema |
| CosmosDB | Unlimited* | Flexible schema |
| Table Storage | 255 properties | Semi-flexible |

*CosmosDB limited by 2 MB document size, not property count.

## 4.2 Pattern Analysis

### Storage Density Patterns

| Data Pattern | Best Service | Rationale |
|--------------|--------------|-----------|
| Few large records (>1 MB each) | Azure SQL | Only option for >2 MB rows |
| Many small records (<1 KB each) | Table Storage | Lowest cost, highest capacity |
| Medium records (1 KB - 1 MB) | CosmosDB | Balanced scale and features |
| Deeply nested JSON | CosmosDB | Native document support |
| Wide tables (>255 columns) | Azure SQL | Higher column limit |
| Narrow tables (<20 columns) | Table Storage | Simplest, cheapest |

### Partition Strategy Impact

| Service | Partition Limit | Impact on Design |
|---------|-----------------|------------------|
| Azure SQL | Table partitions | Manual partition schemes |
| CosmosDB | 20 GB per logical partition | Critical partition key selection |
| Table Storage | Unlimited per partition | Less restrictive |

## 4.3 Scalability Patterns

### Horizontal Scaling

| Service | How It Scales | Limit |
|---------|---------------|-------|
| Azure SQL | Read replicas, sharding | Manual effort |
| CosmosDB | Automatic partitioning | Transparent |
| Table Storage | Automatic | Transparent |

### Vertical Scaling (Record Size)

| Need | Solution |
|------|----------|
| Documents > 2 MB | Azure SQL or split documents |
| Entities > 1 MB | Azure SQL or CosmosDB |
| Rows > 2 GB | External blob storage + reference |

---

# Phase 5: Interpretation & Knowledge

## 5.1 Key Findings

### Finding 1: Storage Capacity Hierarchy

```
Total Storage Capacity (Log Scale):

                   1 TB    10 TB    100 TB    1 PB    5 PB
                    │       │        │        │       │
Azure SQL Basic     ┤ 2 GB
Azure SQL Standard  ────┤ 1 TB
Azure SQL Premium   ─────┤ 4 TB  
Azure SQL Hyperscale────────────┤ 100 TB
CosmosDB            ─────────────────────────────────────→ Unlimited
Table Storage       ───────────────────────────────────┤ 5 PB
```

**Insight**: For pure storage capacity, Table Storage offers the best value. For unlimited growth potential, CosmosDB provides seamless scaling.

### Finding 2: Record Size vs Total Storage Trade-off

| Service | Max Record | Max Total | Trade-off |
|---------|------------|-----------|-----------|
| Azure SQL | 2 GB | 100 TB | Large records, moderate total |
| CosmosDB | 2 MB | Unlimited | Medium records, unlimited total |
| Table Storage | 1 MB | 5 PB | Small records, massive total |

**Insight**: There's an inverse relationship between maximum record size and practical total storage. Services optimized for large records have lower total capacity limits.

### Finding 3: Partition Constraints

| Service | Partition Constraint | Risk Level |
|---------|---------------------|------------|
| Azure SQL | Manual design | Low (familiar patterns) |
| CosmosDB | 20 GB hard limit | High (requires planning) |
| Table Storage | 500 entities/sec/partition | Medium (throughput bound) |

**Insight**: CosmosDB's 20 GB partition limit is the most restrictive and requires careful upfront design. Poor partition key selection can cause data hotspots and require costly migrations.

### Finding 4: Record Count Projections

For 1.2 GB of data with average record sizes:

| Service | Avg Record Size | Estimated Records | Fits in Partition? |
|---------|-----------------|-------------------|-------------------|
| Table Storage | 1 KB | 1,200,000 | ✅ Yes |
| CosmosDB | 1 KB | 1,200,000 | ✅ Yes (if partitioned well) |
| Azure SQL | 1 KB | 1,200,000 | ✅ Yes |

For 100 GB of data:

| Service | Avg Record Size | Estimated Records | Consideration |
|---------|-----------------|-------------------|---------------|
| Table Storage | 1 KB | 100,000,000 | ✅ No issues |
| CosmosDB | 1 KB | 100,000,000 | ⚠️ Need 5+ partitions |
| Azure SQL | 1 KB | 100,000,000 | ✅ Standard tier sufficient |

## 5.2 Decision Framework

### Capacity-Based Selection

```
START
  │
  ▼
Need records > 2 MB? ─── Yes ──▶ AZURE SQL (with LOB storage)
  │
  No
  ▼
Need > 100 TB total? ─── Yes ──▶ TABLE STORAGE or COSMOSDB
  │
  No
  ▼
Need documents 1-2 MB? ─── Yes ──▶ COSMOSDB
  │
  No
  ▼
Need > 255 properties? ─── Yes ──▶ AZURE SQL or COSMOSDB
  │
  No
  ▼
Optimizing for cost? ─── Yes ──▶ TABLE STORAGE
  │
  No
  ▼
Need relational queries? ─── Yes ──▶ AZURE SQL
  │
  No
  ▼
COSMOSDB (best general purpose)
```

### Capacity Recommendations by Data Volume

| Data Volume | Recommended Service | Rationale |
|-------------|---------------------|-----------|
| < 2 GB | Azure SQL Basic | Full SQL, lowest tier |
| 2 GB - 250 GB | Azure SQL Standard | Balanced features/cost |
| 250 GB - 1 TB | Azure SQL Standard S3 | Good performance |
| 1 TB - 4 TB | Azure SQL Premium/BC | High performance |
| 4 TB - 100 TB | Azure SQL Hyperscale | Enterprise scale |
| > 100 TB | Table Storage or CosmosDB | Beyond SQL limits |
| Unlimited growth | CosmosDB | No capacity ceiling |

### Record Size Recommendations

| Record Size | Recommended Service | Rationale |
|-------------|---------------------|-----------|
| < 1 KB | Table Storage | Most cost-effective |
| 1 KB - 100 KB | Any service | All handle well |
| 100 KB - 1 MB | CosmosDB or Azure SQL | Table Storage at limit |
| 1 MB - 2 MB | CosmosDB or Azure SQL | Table Storage excluded |
| 2 MB - 2 GB | Azure SQL | Only option |
| > 2 GB | Azure Blob + reference | External storage required |

## 5.3 Actionable Knowledge

### Storage Capacity Summary Table

| Metric | Azure SQL | CosmosDB | Table Storage |
|--------|-----------|----------|---------------|
| **Max Total Storage** | 100 TB | Unlimited | 5 PB |
| **Max Record Size** | 2 GB | 2 MB | 1 MB |
| **Max Properties/Columns** | 1,024 | Unlimited* | 255 |
| **Max Partition Size** | N/A | 20 GB | Unlimited |
| **Schema** | Fixed | Flexible | Flexible |
| **Best For** | Large records, complex queries | Scalable documents | Massive simple data |

### Cost vs Capacity Matrix

| Requirement | Cheapest Option | Capacity Leader |
|-------------|-----------------|-----------------|
| Bulk storage | Table Storage | Table Storage |
| Large records | Azure SQL Basic | Azure SQL |
| Unlimited scale | Table Storage | CosmosDB |
| Query flexibility | Azure SQL | Azure SQL |

### Migration Considerations

| From → To | Feasibility | Key Challenge |
|-----------|-------------|---------------|
| Table → CosmosDB | Easy | Schema mapping |
| Table → SQL | Moderate | Schema design |
| CosmosDB → SQL | Moderate | Flatten documents |
| CosmosDB → Table | Moderate | Property limit (255) |
| SQL → CosmosDB | Hard | Denormalization |
| SQL → Table | Hard | Lose relational features |

---

# Appendix

## A. Official Documentation Links

| Service | Limits Documentation |
|---------|---------------------|
| Azure SQL | https://docs.microsoft.com/azure/azure-sql/database/resource-limits |
| CosmosDB | https://docs.microsoft.com/azure/cosmos-db/concepts-limits |
| Table Storage | https://docs.microsoft.com/azure/storage/tables/scalability-targets |

## B. Glossary

| Term | Definition |
|------|------------|
| **LOB** | Large Object - SQL Server storage for data > 8 KB |
| **Partition Key** | CosmosDB/Table Storage key for data distribution |
| **RU** | Request Unit - CosmosDB throughput measure |
| **DTU** | Database Transaction Unit - Azure SQL performance measure |
| **vCore** | Virtual Core - Azure SQL compute measure |
| **Entity** | Table Storage term for a row/record |
| **Document** | CosmosDB term for a JSON record |

## C. Size Reference

| Human-Readable | Bytes |
|----------------|-------|
| 1 KB | 1,024 |
| 1 MB | 1,048,576 |
| 1 GB | 1,073,741,824 |
| 1 TB | 1,099,511,627,776 |
| 1 PB | 1,125,899,906,842,624 |

---

*Document generated using KDD methodology*
*Analysis Date: February 5, 2026*
*Version: 1.0*
