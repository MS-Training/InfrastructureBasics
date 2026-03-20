# Azure Data Storage Redundancy & Replication Analysis
## KDD (Knowledge Discovery in Databases) Methodology Report

---

## Executive Summary

This document analyzes and compares the regional redundancy and replication capabilities of Azure SQL Database, CosmosDB, and Azure Table Storage using the KDD methodology.

### Key Findings

| Service | Redundancy Options | Multi-Region Active | Auto-Failover |
|---------|-------------------|---------------------|---------------|
| **Azure SQL** | LRS, ZRS, Geo-Replica | ❌ Read-only secondary | ✅ Failover Groups |
| **CosmosDB** | Multi-region active-active | ✅ Yes | ✅ Automatic |
| **Table Storage** | LRS, ZRS, GRS, GZRS, RA-GRS, RA-GZRS | ❌ Read-only secondary | ⚠️ Manual |

---

# Phase 1: Selection

## 1.1 Problem Definition

**Objective**: Analyze and compare the data redundancy, replication, and disaster recovery capabilities of Azure's primary database services to guide high-availability architectural decisions.

## 1.2 Scope

| Parameter | Included |
|-----------|----------|
| Storage redundancy types | ✅ |
| Cross-region replication | ✅ |
| Read/write capabilities per region | ✅ |
| Failover mechanisms | ✅ |
| Recovery Point Objective (RPO) | ✅ |
| Recovery Time Objective (RTO) | ✅ |
| SLA guarantees | ✅ |

## 1.3 Key Questions

1. What redundancy options does each service offer?
2. Can data be replicated across regions?
3. Is multi-region write supported?
4. What are the failover capabilities?
5. What are the RPO/RTO guarantees?

---

# Phase 2: Preprocessing

## 2.1 Terminology Standardization

| Term | Definition |
|------|------------|
| **LRS** | Locally Redundant Storage - 3 copies in single datacenter |
| **ZRS** | Zone-Redundant Storage - 3 copies across availability zones |
| **GRS** | Geo-Redundant Storage - 6 copies (3 primary + 3 secondary region) |
| **RA-GRS** | Read-Access Geo-Redundant Storage - GRS with read access to secondary |
| **GZRS** | Geo-Zone-Redundant Storage - ZRS + async replication to secondary |
| **RA-GZRS** | Read-Access GZRS - GZRS with read access to secondary |
| **RPO** | Recovery Point Objective - Maximum acceptable data loss (time) |
| **RTO** | Recovery Time Objective - Maximum acceptable downtime |
| **Active-Active** | Both regions accept reads AND writes |
| **Active-Passive** | Primary accepts writes, secondary is read-only or standby |

## 2.2 SLA Definitions

| SLA Level | Monthly Downtime Allowed |
|-----------|-------------------------|
| 99.9% | 43.8 minutes |
| 99.95% | 21.9 minutes |
| 99.99% | 4.3 minutes |
| 99.999% | 26 seconds |

---

# Phase 3: Transformation

## 3.1 Azure SQL Database Redundancy

### Storage Redundancy Options

| Tier | Redundancy Options | Default |
|------|-------------------|---------|
| Basic | LRS | LRS |
| Standard | LRS, ZRS | LRS |
| Premium | LRS, ZRS | LRS |
| Business Critical | LRS, ZRS | ZRS |
| Hyperscale | LRS, ZRS, GRS, GZRS | LRS |

### Replication Options

| Feature | Description | RPO | RTO |
|---------|-------------|-----|-----|
| **Local Redundancy** | 3 copies within datacenter | 0 | Minutes |
| **Zone Redundancy** | 3 copies across AZs | 0 | Minutes |
| **Active Geo-Replication** | Up to 4 readable secondaries | < 5 sec | User-controlled |
| **Failover Groups** | Automatic failover with DNS | < 5 sec | < 1 hour |
| **Hyperscale Geo-Replica** | Read-scale replicas | < 5 sec | Minutes |

### Geo-Replication Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Azure SQL Geo-Replication                               │
│                                                                             │
│   Primary Region (East US)              Secondary Region (West US)         │
│   ┌─────────────────────┐              ┌─────────────────────┐             │
│   │   Primary Database  │  ──Async──▶  │  Secondary Database │             │
│   │   ✅ Read/Write     │  Replication │  ✅ Read-Only       │             │
│   └─────────────────────┘              └─────────────────────┘             │
│                                                                             │
│   Failover Group: Automatic DNS failover                                   │
│   RPO: < 5 seconds | RTO: < 1 hour                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Failover Group Configuration

| Setting | Options |
|---------|---------|
| Failover policy | Automatic or Manual |
| Grace period | 1-24 hours (automatic mode) |
| Read-only endpoint | Separate DNS for read workloads |
| Failback | Manual or Automatic |

### Azure SQL SLAs

| Configuration | Availability SLA |
|---------------|------------------|
| Single database (no AZ) | 99.99% |
| Zone-redundant | 99.995% |
| Failover group (multi-region) | 99.995% |
| Business Critical (zone-redundant) | 99.995% |

---

## 3.2 CosmosDB Redundancy

### Replication Architecture

| Configuration | Description |
|---------------|-------------|
| **Single Region** | 4 replicas within region |
| **Multi-Region (Single Write)** | 1 write region + N read regions |
| **Multi-Region (Multi-Write)** | All regions accept writes |
| **Availability Zones** | Replicas spread across 3 AZs |

### Multi-Region Write Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CosmosDB Multi-Region Writes                            │
│                                                                             │
│   Region: East US                      Region: West Europe                  │
│   ┌─────────────────────┐              ┌─────────────────────┐             │
│   │   ✅ Read/Write     │ ◀──Sync───▶  │   ✅ Read/Write     │             │
│   │   Primary Copy      │  Replication │   Primary Copy      │             │
│   └─────────────────────┘              └─────────────────────┘             │
│            │                                      │                         │
│            │              Region: Southeast Asia  │                         │
│            │              ┌─────────────────────┐ │                         │
│            └────────────▶ │   ✅ Read/Write     │◀┘                         │
│                           │   Primary Copy      │                           │
│                           └─────────────────────┘                           │
│                                                                             │
│   All regions active | Automatic conflict resolution                       │
│   RPO: ~0 (strong) to minutes (eventual) | RTO: ~0 (automatic)             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Consistency Levels & Replication

| Consistency Level | Replication Behavior | RPO |
|-------------------|---------------------|-----|
| **Strong** | Synchronous, globally consistent | 0 |
| **Bounded Staleness** | Async with lag guarantee | K versions or T time |
| **Session** | Consistent within session | Session-scoped |
| **Consistent Prefix** | Ordered, no gaps | Seconds |
| **Eventual** | Fastest, eventually consistent | Seconds to minutes |

### Failover Options

| Feature | Single-Write | Multi-Write |
|---------|--------------|-------------|
| Automatic failover | ✅ Configurable | N/A (all regions active) |
| Manual failover | ✅ Yes | N/A |
| Failover priority | ✅ Configurable list | N/A |
| Service-managed failover | ✅ On region outage | ✅ Built-in |

### CosmosDB SLAs

| Configuration | Read SLA | Write SLA | Combined |
|---------------|----------|-----------|----------|
| Single region | 99.99% | 99.99% | 99.99% |
| Multi-region (single write) | 99.999% | 99.99% | 99.99% |
| Multi-region (multi-write) | 99.999% | 99.999% | 99.999% |
| With Availability Zones | +Higher within region | +Higher | +Higher |

---

## 3.3 Azure Table Storage Redundancy

### Storage Redundancy Options

| Option | Copies | Regions | Read Access | Cost Multiplier |
|--------|--------|---------|-------------|-----------------|
| **LRS** | 3 | 1 (single DC) | Primary only | 1x |
| **ZRS** | 3 | 1 (3 AZs) | Primary only | ~1.25x |
| **GRS** | 6 | 2 | Primary only | ~2x |
| **RA-GRS** | 6 | 2 | Both regions | ~2.1x |
| **GZRS** | 6 | 2 (primary ZRS) | Primary only | ~2.3x |
| **RA-GZRS** | 6 | 2 (primary ZRS) | Both regions | ~2.5x |

### Replication Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Table Storage RA-GZRS Replication                       │
│                                                                             │
│   Primary Region (East US)              Secondary Region (West US)         │
│   ┌─────────────────────┐              ┌─────────────────────┐             │
│   │  Availability Zone 1│              │                     │             │
│   │  ┌─────────────┐    │              │  ┌─────────────┐    │             │
│   │  │   Copy 1    │    │   ──Async──▶ │  │   Copy 4    │    │             │
│   │  └─────────────┘    │  Replication │  └─────────────┘    │             │
│   ├─────────────────────┤              │  ┌─────────────┐    │             │
│   │  Availability Zone 2│              │  │   Copy 5    │    │             │
│   │  ┌─────────────┐    │              │  └─────────────┘    │             │
│   │  │   Copy 2    │    │              │  ┌─────────────┐    │             │
│   │  └─────────────────┘│              │  │   Copy 6    │    │             │
│   ├─────────────────────┤              │  └─────────────┘    │             │
│   │  Availability Zone 3│              │     Read-Only       │             │
│   │  ┌─────────────┐    │              │   (RA-GRS/RA-GZRS)  │             │
│   │  │   Copy 3    │    │              └─────────────────────┘             │
│   │  └─────────────┘    │                                                  │
│   │     Read/Write      │                                                  │
│   └─────────────────────┘                                                  │
│                                                                             │
│   RPO: ~15 minutes (async) | RTO: Manual failover required                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Failover Behavior

| Scenario | Behavior | RTO |
|----------|----------|-----|
| Primary AZ failure (ZRS) | Automatic | Seconds |
| Primary region failure (GRS) | Manual failover required | Hours |
| Microsoft-initiated failover | Automatic (rare, major outages) | Hours |
| Customer-initiated failover | Manual via portal/API | Minutes |

### Table Storage SLAs

| Redundancy | Read SLA | Write SLA |
|------------|----------|-----------|
| LRS | 99.9% | 99.9% |
| ZRS | 99.9% | 99.9% |
| GRS/GZRS | 99.9% | 99.9% |
| RA-GRS/RA-GZRS | 99.99% (read) | 99.9% (write) |

---

# Phase 4: Data Mining

## 4.1 Comparative Analysis

### Redundancy Feature Matrix

| Feature | Azure SQL | CosmosDB | Table Storage |
|---------|-----------|----------|---------------|
| Local copies (same DC) | 3 | 4 | 3 |
| Zone redundancy | ✅ Optional | ✅ Optional | ✅ ZRS/GZRS |
| Cross-region replication | ✅ Geo-replica | ✅ Multi-region | ✅ GRS |
| Multi-region writes | ❌ No | ✅ Yes | ❌ No |
| Read from secondary | ✅ Yes | ✅ Yes | ✅ RA-GRS only |
| Automatic failover | ✅ Failover Groups | ✅ Built-in | ⚠️ Limited |
| Configurable regions | Up to 4 | Unlimited | 1 pair (fixed) |

### RPO/RTO Comparison

| Metric | Azure SQL | CosmosDB | Table Storage |
|--------|-----------|----------|---------------|
| **RPO (best case)** | < 5 seconds | 0 (strong consistency) | ~15 minutes |
| **RPO (typical)** | < 5 seconds | Seconds (eventual) | ~15 minutes |
| **RTO (automatic)** | < 1 hour | ~0 (multi-write) | N/A (manual) |
| **RTO (manual)** | Minutes | Minutes | Minutes-Hours |

### Multi-Region Capability Comparison

```
Multi-Region Write Capability:

CosmosDB      ████████████████████████████████████████  Full Active-Active
Azure SQL     ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░  Active-Passive (read secondary)
Table Storage ████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░  Active-Passive (RA-GRS read)
              |         |         |         |         |
              0%       25%       50%       75%      100%
              Passive          Capabilities         Active-Active
```

### Failover Automation Level

```
Failover Automation:

CosmosDB (Multi-Write)  ████████████████████████████████████████  Fully Automatic
CosmosDB (Single-Write) ██████████████████████████████░░░░░░░░░░  Configurable Auto
Azure SQL (Failover Grp)██████████████████████████████░░░░░░░░░░  Configurable Auto
Azure SQL (Geo-Replica) ████████████████░░░░░░░░░░░░░░░░░░░░░░░░  Manual
Table Storage (RA-GRS)  ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  Manual
                        |         |         |         |         |
                        Manual   Semi-Auto  Auto     Full-Auto
```

## 4.2 Pattern Analysis

### High Availability Patterns

| Pattern | Best Service | Configuration |
|---------|--------------|---------------|
| Zero data loss (RPO=0) | CosmosDB | Strong consistency, multi-region |
| Near-zero downtime (RTO≈0) | CosmosDB | Multi-region multi-write |
| Cost-optimized HA | Table Storage | RA-GRS |
| SQL with auto-failover | Azure SQL | Failover Groups |
| Global write distribution | CosmosDB | Multi-write enabled |

### Disaster Recovery Patterns

| Scenario | Azure SQL | CosmosDB | Table Storage |
|----------|-----------|----------|---------------|
| Regional outage | Failover Group | Automatic | Manual failover |
| AZ outage | Zone-redundant | Automatic | ZRS automatic |
| Datacenter outage | Geo-replica | Automatic | GRS (async) |
| Data corruption | Point-in-time restore | Point-in-time | Soft delete/versioning |

## 4.3 Cost Analysis for Redundancy

### Relative Cost Multipliers

| Service | Base | + Zone Redundancy | + Geo Redundancy | + Multi-Region Active |
|---------|------|-------------------|------------------|----------------------|
| Azure SQL | 1x | ~1.0x (same price) | ~2x (geo-replica) | N/A |
| CosmosDB | 1x | ~1.25x | ~2x per region | ~2x per write region |
| Table Storage | 1x | ~1.25x (ZRS) | ~2x (GRS) | N/A |

### Cost-Optimized Redundancy Recommendations

| Budget | Best Option | Configuration |
|--------|-------------|---------------|
| Minimal | Table Storage LRS | Accept 99.9% SLA |
| Low | Table Storage ZRS | Zone protection |
| Medium | Table Storage RA-GZRS | Full geo-redundancy |
| Medium | Azure SQL + Zone Redundancy | Regional HA |
| High | Azure SQL + Failover Group | Multi-region |
| Premium | CosmosDB Multi-Region | Maximum availability |

## 4.4 SLA Comparison

### Availability SLA by Configuration

| Configuration | Azure SQL | CosmosDB | Table Storage |
|---------------|-----------|----------|---------------|
| Single region, no zones | 99.99% | 99.99% | 99.9% |
| Single region + zones | 99.995% | 99.99%+ | 99.9% |
| Multi-region (read) | 99.995% | 99.999% | 99.99% (RA-GRS) |
| Multi-region (write) | N/A | 99.999% | N/A |

```
SLA Comparison (9's of availability):

CosmosDB Multi-Write    ██████████████████████████████████████  99.999% (5 nines)
CosmosDB Multi-Read     ██████████████████████████████████████  99.999%
Azure SQL Zone+Failover ████████████████████████████████░░░░░░  99.995%
Azure SQL Zone          ████████████████████████████████░░░░░░  99.995%
Azure SQL Basic         ██████████████████████████████░░░░░░░░  99.99% (4 nines)
Table Storage RA-GRS    ██████████████████████████████░░░░░░░░  99.99%
Table Storage LRS       ████████████████████████░░░░░░░░░░░░░░  99.9% (3 nines)
                        99.9%    99.95%   99.99%   99.995%  99.999%
```

---

# Phase 5: Interpretation & Knowledge

## 5.1 Key Findings

### Finding 1: CosmosDB Leads in Multi-Region Capability

CosmosDB is the only service offering true **active-active multi-region writes**:

| Capability | Azure SQL | CosmosDB | Table Storage |
|------------|-----------|----------|---------------|
| Write to multiple regions simultaneously | ❌ | ✅ | ❌ |
| Automatic conflict resolution | N/A | ✅ | N/A |
| Unlimited region count | ❌ (max 4) | ✅ | ❌ (1 pair) |

**Insight**: For globally distributed write workloads, CosmosDB is the only native Azure option.

### Finding 2: Table Storage Offers Best Cost-to-Redundancy Ratio

| Service | Cost for Geo-Redundancy | Read from Secondary |
|---------|------------------------|---------------------|
| Table Storage (RA-GZRS) | ~2.5x base | ✅ Yes |
| Azure SQL (Geo-Replica) | ~2x compute | ✅ Yes |
| CosmosDB (2 regions) | ~2x RUs | ✅ Yes |

**Insight**: For simple redundancy needs, Table Storage provides the most cost-effective geo-redundancy.

### Finding 3: RPO/RTO Trade-offs

| Priority | Best Service | Trade-off |
|----------|--------------|-----------|
| Lowest RPO (zero data loss) | CosmosDB (strong) | Higher latency |
| Lowest RTO (instant failover) | CosmosDB (multi-write) | Higher cost |
| Balanced RPO/RTO | Azure SQL (Failover Groups) | < 5s RPO, < 1h RTO |
| Cost-optimized | Table Storage (RA-GRS) | ~15 min RPO, hours RTO |

```
RPO vs RTO Trade-off:

                    Low RTO ◀─────────────────────────────▶ High RTO
                    (Fast Recovery)                    (Slow Recovery)
    Low RPO    ┌──────────────────────────────────────────────────────┐
   (No Loss)   │  CosmosDB          Azure SQL                        │
               │  Multi-Write       Failover Groups                  │
               │                                                      │
               │                                                      │
               │                    Azure SQL                        │
               │                    Geo-Replica                      │
               │                                                      │
               │                                      Table Storage  │
    High RPO   │                                      RA-GRS         │
   (Some Loss) └──────────────────────────────────────────────────────┘
```

### Finding 4: Automation Levels Vary Significantly

| Service | Automatic Failover | Configuration Required |
|---------|-------------------|----------------------|
| CosmosDB Multi-Write | ✅ Always on | Enable multi-write |
| CosmosDB Single-Write | ✅ Configurable | Set failover priority |
| Azure SQL Failover Groups | ✅ Configurable | Create failover group |
| Azure SQL Geo-Replica | ❌ Manual | None (always manual) |
| Table Storage | ⚠️ MS-initiated only | Enable RA-GRS |

### Finding 5: Regional Pairing Constraints

| Service | Region Selection | Flexibility |
|---------|-----------------|-------------|
| CosmosDB | Any Azure region | ✅ Full control |
| Azure SQL | Any Azure region | ✅ Full control |
| Table Storage | Fixed pairs only | ❌ Limited |

**Insight**: Table Storage uses Microsoft-defined region pairs (e.g., East US ↔ West US). You cannot choose custom region pairs for geo-replication.

## 5.2 Decision Framework

### Redundancy Selection Flowchart

```
START
  │
  ▼
Need multi-region writes? ─── Yes ──▶ COSMOSDB (Multi-Write)
  │                                   Cost: High | SLA: 99.999%
  No
  ▼
Need RPO < 1 minute? ─── Yes ──▶ COSMOSDB or AZURE SQL (Failover Groups)
  │                              Cost: Medium-High
  No
  ▼
Need automatic failover? ─── Yes ──▶ COSMOSDB or AZURE SQL (Failover Groups)
  │                                  Cost: Medium-High
  No
  ▼
Need to read from secondary? ─── Yes ──▶ TABLE STORAGE (RA-GRS/RA-GZRS)
  │                                       Cost: Low-Medium
  No
  ▼
Need zone protection only? ─── Yes ──▶ Any service with ZRS
  │                                    Cost: Low
  No
  ▼
TABLE STORAGE LRS or AZURE SQL Basic
Cost: Lowest
```

### Recommendation Matrix by Scenario

| Scenario | Recommended Service | Configuration |
|----------|---------------------|---------------|
| Global e-commerce (writes anywhere) | CosmosDB | Multi-region multi-write |
| Regional app with DR | Azure SQL | Failover Groups |
| Backup/archive data | Table Storage | GRS or RA-GRS |
| Cost-sensitive with HA | Table Storage | RA-GZRS |
| Mission-critical SQL app | Azure SQL | Business Critical + Failover Groups |
| IoT data with global reads | CosmosDB | Multi-region single-write |
| Simple key-value with DR | Table Storage | RA-GRS |

### SLA-Based Selection

| Required SLA | Minimum Configuration |
|--------------|----------------------|
| 99.9% | Any service, LRS |
| 99.95% | Azure SQL zone-redundant |
| 99.99% | Azure SQL Failover Groups or CosmosDB |
| 99.999% | CosmosDB multi-region multi-write |

## 5.3 Actionable Knowledge

### Summary Comparison Table

| Capability | Azure SQL | CosmosDB | Table Storage |
|------------|-----------|----------|---------------|
| **Local redundancy** | ✅ 3 copies | ✅ 4 copies | ✅ 3 copies |
| **Zone redundancy** | ✅ Optional | ✅ Optional | ✅ ZRS |
| **Geo-replication** | ✅ Geo-replica | ✅ Multi-region | ✅ GRS |
| **Multi-region writes** | ❌ No | ✅ Yes | ❌ No |
| **Read from secondary** | ✅ Yes | ✅ Yes | ✅ RA-GRS |
| **Auto failover** | ✅ Failover Groups | ✅ Built-in | ⚠️ Limited |
| **Custom region pairs** | ✅ Yes | ✅ Yes | ❌ No |
| **Best RPO** | < 5 seconds | 0 (strong) | ~15 minutes |
| **Best RTO** | < 1 hour | ~0 seconds | Hours |
| **Best SLA** | 99.995% | 99.999% | 99.99% |

### Quick Reference: Redundancy Options

| Need | Azure SQL | CosmosDB | Table Storage |
|------|-----------|----------|---------------|
| Cheapest | Basic (LRS) | Single region | LRS |
| Zone HA | Zone-redundant tier | Enable AZ | ZRS |
| Geo DR | Geo-replica | Add region | GRS |
| Read offload | Geo-replica | Multi-region | RA-GRS |
| Auto failover | Failover Groups | Multi-write | ❌ Not available |
| Maximum HA | BC + Failover Groups | Multi-write + AZ | RA-GZRS |

---

# Appendix

## A. Official Documentation

| Service | Documentation |
|---------|---------------|
| Azure SQL | https://docs.microsoft.com/azure/azure-sql/database/high-availability-sla |
| CosmosDB | https://docs.microsoft.com/azure/cosmos-db/high-availability |
| Table Storage | https://docs.microsoft.com/azure/storage/common/storage-redundancy |

## B. Region Pairs (Table Storage)

| Primary Region | Paired Region |
|----------------|---------------|
| East US | West US |
| East US 2 | Central US |
| West US 2 | West Central US |
| North Europe | West Europe |
| Southeast Asia | East Asia |
| UK South | UK West |
| Australia East | Australia Southeast |

## C. Glossary

| Term | Definition |
|------|------------|
| **Active-Active** | All regions accept read and write operations |
| **Active-Passive** | Primary handles writes, secondary is standby or read-only |
| **Failover** | Switching operations from primary to secondary region |
| **Failback** | Returning operations to original primary region |
| **RPO** | Recovery Point Objective - acceptable data loss window |
| **RTO** | Recovery Time Objective - acceptable downtime |
| **Geo-Replication** | Copying data to geographically distant region |
| **Zone Redundancy** | Distributing copies across availability zones |

## D. RPO/RTO Quick Reference

| Service + Config | RPO | RTO |
|------------------|-----|-----|
| CosmosDB Multi-Write (Strong) | 0 | 0 |
| CosmosDB Multi-Write (Eventual) | Seconds | 0 |
| CosmosDB Single-Write | Seconds | Seconds-Minutes |
| Azure SQL Failover Groups | < 5 sec | < 1 hour |
| Azure SQL Geo-Replica | < 5 sec | User-controlled |
| Table Storage RA-GZRS | ~15 min | Hours |
| Table Storage GRS | ~15 min | Hours |

---

*Document generated using KDD methodology*
*Analysis Date: February 5, 2026*
*Version: 1.0*
