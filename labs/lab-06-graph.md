# Lab 06 — Graph: Fraud Rings & Centrality (GQL)

**Goal:** use the ontology's companion graph to find fraud rings and influential (hub) merchants — analysis that is awkward in SQL but natural in a graph.

**Duration:** ~25 min · **Track:** code (GQL) · **Status:** historical query results verified; rerun on the live companion graph

---

## Facilitator track

### Story
Fraud is a network phenomenon: rings of cards hitting the same colluding merchants, hub merchants touched by disproportionate fraud. The ontology graph lets analysts (and agents) ask relationship questions directly.

### Expected results
| Query | Result |
|---|---|
| Hub merchant by fraud transactions | `MER-0026` = 69 fraud txns |
| Fraud rings by distinct members | `MER-0041` = 7 members (matches seeded ring) |
| Customers within 2 hops of 11 high-risk merchants | 1800 |

### Gotchas
- **GQL `GROUP BY`:** when `RETURN` mixes a non-aggregated key with aggregates, `GROUP BY` must reference the **RETURN alias** (not `m.merchantId` → "mismatched input '.'"; not omitted → "identifier neither in GROUP BY nor aggregation"). Pure-aggregate queries (only `count()`, no bare key) need **no** `GROUP BY`.
- **Paging:** heavy queries return status `02000` "retry with continuation token" → re-POST `{query, continuationToken}` until the token is null. Filter-first / 2-hop queries return in one page.
- This is also the AI-agent substrate: the data agent (Lab 08) turns natural language into exactly these GQL walks.

---

## Attendee track

### Run the ring & centrality queries
```powershell
cd fabric-iq-banking-poc/06-graph
./graph_ring_queries.ps1
```

The script runs three GQL queries against `POST /workspaces/{ws}/GraphModels/{graphId}/executeQuery?preview=true`:
1. Hub merchants ranked by fraud transactions.
2. Fraud rings ranked by distinct member cards.
3. Blast-radius: customers within 2 hops of high-risk merchants.

### Check yourself
- `MER-0026` tops the hub list; `MER-0041` has 7 ring members.
- If a query returns status `02000`, the script follows the continuation token automatically — confirm the final aggregate count.
- Record fresh output from `DemoOntology_graph_...` before presenting these values as current.
