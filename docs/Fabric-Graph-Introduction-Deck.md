# Microsoft Fabric Graph: A Simple Introduction

**Audience:** customers and business or technical stakeholders new to graphs.  
**Length:** 10 slides, approximately 10-15 minutes.  
**Documentation reviewed:** October 8, 2026.

## Presentation Guide

Use each numbered slide as a PowerPoint slide. Copy the **On-slide** content into the deck; use **Speaker notes**, **Suggested visual**, and **Sources** in the presenter notes. This introduction contains no deployment steps, code, or live-demo requirements.

---

### Slide 01: What Is Graph in Microsoft Fabric?

**On-slide**

**A way to understand your data through its connections.**

- Represents entities, such as customers and products, as **nodes**.
- Represents connections between entities as **edges**.
- Helps you model, visualize, and analyze connected data in Fabric.
- Uses structured data in OneLake to build a queryable graph.

**Speaker notes:** A graph here is not a bar chart or line chart. It is a network of entities and their relationships. Fabric Graph helps answer questions about how things are connected.

**Suggested visual:** Three labeled circles: Customer, Transaction, and Merchant, connected by arrows.

**Sources:** [Graph overview](https://learn.microsoft.com/fabric/graph/overview), [How Graph works](https://learn.microsoft.com/fabric/graph/how-graph-works).

---

### Slide 02: Why Use a Graph?

**On-slide**

**Sometimes the connection matters as much as the individual record.**

- Uncover shared connections and relationship patterns.
- Follow paths across several related entities.
- Understand which entities could be affected by a change or risk.
- Make complex relationships easier to explore and explain.

**Speaker notes:** SQL can answer relationship questions too. Graph makes paths and connected patterns natural to express and visualize. It is useful when relationships drive the question, not a requirement for every dataset or a promise of faster performance for every query.

**Suggested visual:** A single customer highlighted within a small network of accounts, transactions, and merchants.

**Sources:** [What is a graph database?](https://learn.microsoft.com/fabric/graph/graph-database).

---

### Slide 03: Basic Concepts

**On-slide**

| Concept | Meaning | Example |
| --- | --- | --- |
| Node | An entity in the network | A customer or merchant |
| Edge | A connection between two nodes | Customer makes Transaction |
| Label | The type of node or edge | Customer, makes |
| Property | A detail attached to a node or edge | Name, amount, relationship date |
| Key | Identifies a node from its source data | Customer ID |
| Path / hop | A sequence of connections / one step along it | Customer -> Transaction -> Merchant |

**Speaker notes:** Fabric Graph uses a labeled property graph model. Both nodes and edges can carry properties. For example, a customer can have a name, while a relationship can have a date. Keys ensure connections point to the correct entities.

**Suggested visual:** A Customer node with an ID and name, an arrow labeled makes, and a Transaction node with an amount.

**Sources:** [Labeled property graphs](https://learn.microsoft.com/fabric/graph/graph-data-models), [Graph quickstart](https://learn.microsoft.com/fabric/graph/quickstart).

---

### Slide 04: A Simple Example

**On-slide**

**Customer -> makes -> Transaction -> at -> Merchant**

- A customer makes a transaction at a merchant.
- Multiple customers may transact at the same merchant.
- One customer may connect to several merchants.
- Following these links reveals a connected network.

**Example question:** Which customers transacted at the same merchant?

**Speaker notes:** This is an illustrative model, not a live result. The customer-to-merchant path has two hops. Shared connections can be useful for analysis, but sharing a merchant does not, by itself, imply suspicious activity.

**Suggested visual:** Two customers, each connected through a separate transaction to the same merchant. Show the merchant as the shared connection.

---

### Slide 05: How Fabric Graph Works

**On-slide**

**Source tables -> Define nodes and edges -> Save / refresh -> Explore**

- Select supported source tables in Fabric.
- Map table rows and keys to nodes and relationships.
- Save the model to load data and build the queryable graph.
- Refresh the graph when source data changes.

**Speaker notes:** The queryable graph is a read-optimized representation built from source data. It does not instantly reflect every source update. Saving structural changes rebuilds the graph; refresh keeps loaded data current. Preparing reliable keys and relationships remains important.

**Suggested visual:** A four-step horizontal flow with source tables, a network model, a refresh symbol, and connected results.

**Sources:** [How Graph works](https://learn.microsoft.com/fabric/graph/how-graph-works), [Manage and refresh data](https://learn.microsoft.com/fabric/graph/manage-data).

---

### Slide 06: How Do Users Explore a Graph?

**On-slide**

- **Visual query builder:** select entities and connections without writing queries.
- **GQL code editor:** describe relationship patterns using Graph Query Language.
- **Results:** inspect connected diagrams or tabular answers.
- **Fabric Data Agent, preview:** ask natural-language questions over a graph.

**Speaker notes:** GQL is an ISO-standardized language for graph queries; Fabric supports a documented subset. Natural-language access through Data Agent is optional and in preview. Review generated queries and validate answers, particularly for business-critical questions.

**Suggested visual:** Three simple labels feeding the same network: Visual exploration, GQL, and Natural language (preview).

**Sources:** [How Graph works](https://learn.microsoft.com/fabric/graph/how-graph-works), [Query builder tutorial](https://learn.microsoft.com/fabric/graph/tutorial-query-builder), [Data Agent graph sources](https://learn.microsoft.com/fabric/data-science/data-agent-add-datasources?tabs=gql).

---

### Slide 07: Where Can Graphs Be Useful?

**On-slide**

| Use case | Example relationship question |
| --- | --- |
| Fraud and risk investigation | Which accounts share transactions, merchants, or devices? |
| Customer understanding | How are customers connected to products and interactions? |
| Recommendations | What products connect to similar customers' purchases? |
| Supply chain analysis | Which products depend on a disrupted supplier? |
| IT dependency analysis | Which services could be affected by a component failure? |
| Knowledge assistants | What connected facts help answer a multi-step question? |

**Speaker notes:** These are potential applications, not prebuilt solutions or guaranteed outcomes. They require suitable source data and modeling. Graph patterns can supply evidence for fraud review, recommendation candidates, or dependency analysis; application logic and evaluation are still needed.

**Suggested visual:** Use the table as the slide; avoid adding a separate diagram that makes it crowded.

**Sources:** [Common uses for graph databases](https://learn.microsoft.com/fabric/graph/graph-database#common-uses-for-graph-databases), [Graph overview](https://learn.microsoft.com/fabric/graph/overview).

---

### Slide 08: Example Use Case: Banking and Payments

**On-slide**

**Connect payments activity with a broader customer risk picture.**

- Model customers, accounts, transactions, merchants, and loans.
- Follow customer connections to a merchant flagged for review.
- Identify customers who also have fraud alerts or loan delinquency records.
- Show the relationship path that supports an investigation.

**Speaker notes:** This is an illustrative banking use case, not a claim about a customer's systems. A consistent customer identity must connect the source domains. Connected records identify a review cohort, not proof of fraud or causation; status and time windows must be defined.

**Suggested visual:** Customer connected to a payments branch (Transaction -> Merchant) and a lending branch (Loan -> Delinquency record).

**Sources:** [Fraud and risk network use cases](https://learn.microsoft.com/fabric/graph/graph-database#common-uses-for-graph-databases).

---

### Slide 09: When Is Fabric Graph a Good Fit?

**On-slide**

**Use Graph when the question is about connections, paths, or impact.**

- Your data contains meaningful relationships and reliable entity keys.
- Questions involve several connected steps or shared neighbors.
- Your team needs to explore and explain those connections.
- You want graph analytics within the Fabric and OneLake environment.

**Keep SQL and BI for straightforward reporting and governed metrics.**

**Speaker notes:** Fabric Graph complements other Fabric workloads. It does not require an external graph database for this workflow, but graph operations and cache storage still incur cost. Check current prerequisites, region availability, permissions, refresh needs, and limitations. Direct Power BI-to-Graph visualization is not currently supported; do not imply automatic reuse of semantic-model security.

**Suggested visual:** Two columns: "Connections and paths: Graph" and "Totals and reporting: SQL / BI".

**Sources:** [When to consider a graph database](https://learn.microsoft.com/fabric/graph/graph-database#when-to-consider-a-graph-database), [Graph overview](https://learn.microsoft.com/fabric/graph/overview), [Current limitations](https://learn.microsoft.com/fabric/graph/limitations).

---

### Slide 10: Key Takeaways

**On-slide**

- **What:** Graph models entities and their relationships in Fabric.
- **Why:** It helps uncover connections and explain multi-step paths.
- **How:** Define nodes and edges, load data, then explore visually or with GQL.
- **Where:** Risk, customer insights, recommendations, dependencies, and AI assistants.

**Start with one business question where relationships matter.**

**Speaker notes:** Begin with a small, well-understood dataset and compare results with an existing trusted calculation. A graph is valuable when it makes a useful relationship question easier to answer and explain.

**Suggested visual:** A small connected network beside the four takeaways.

---

## Presenter Reference: Official Documentation

These links support the presentation; they are not additional slides.

- [Graph in Microsoft Fabric overview](https://learn.microsoft.com/fabric/graph/overview)
- [What is a graph database?](https://learn.microsoft.com/fabric/graph/graph-database)
- [Labeled property graphs](https://learn.microsoft.com/fabric/graph/graph-data-models)
- [How Graph works](https://learn.microsoft.com/fabric/graph/how-graph-works)
- [Create your first graph](https://learn.microsoft.com/fabric/graph/quickstart)
- [Query the graph with the query builder](https://learn.microsoft.com/fabric/graph/tutorial-query-builder)
- [Manage and refresh graph data](https://learn.microsoft.com/fabric/graph/manage-data)
- [Add and configure Data Agent sources](https://learn.microsoft.com/fabric/data-science/data-agent-add-datasources?tabs=gql)
- [Current Graph limitations](https://learn.microsoft.com/fabric/graph/limitations)

**Scope note:** This deck is about the Fabric Graph item, not Microsoft Graph, a Power BI chart, or Eventhouse's separate KQL graph features. Fabric Graph uses a labeled property graph, not RDF. Recheck release status and limitations before presenting; graph-powered Data Agent access is documented as preview.