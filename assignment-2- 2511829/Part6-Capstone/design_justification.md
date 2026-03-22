 Design Justification

## Storage Systems

Each goal has meaningfully different data characteristics, so no single storage system could serve all of them well. The storage layer was designed around matching each database's strengths to its workload.

For **Goal 1 (readmission risk prediction)**, structured patient records are stored in **PostgreSQL**. The data is relational, highly normalized, and must satisfy HL7 FHIR schema constraints. ACID guarantees protect clinical record integrity during concurrent writes. A **Feast feature store** sits on top, caching pre-computed ML features so training and inference pipelines avoid repeatedly hitting raw EHR tables.

For **Goal 2 (natural language patient queries)**, record chunks are embedded and stored in **Pinecone**, a managed vector database. Semantic search over clinical notes is a nearest-neighbor problem — a relational database cannot perform it efficiently. Pinecone handles million-scale vector retrieval in milliseconds, making real-time RAG practical. Raw documents remain in Delta Lake as the source of truth.

For **Goal 3 (monthly management reports)**, aggregated data flows into **Snowflake**. These queries scan months of history across bed occupancy, cost, and staffing tables — a textbook OLAP workload requiring columnar storage and parallel execution. **Delta Lake on S3** sits upstream as the staging layer, providing ACID transactions for large-scale corrections and time-travel queries for audits.

For **Goal 4 (real-time ICU vitals)**, device telemetry is written to **TimescaleDB**, a PostgreSQL extension built for time-series data. It compresses sequential sensor readings far more efficiently than a row store and supports time-bucketed aggregations natively, which the alerting engine depends on.

## OLTP vs OLAP Boundary

The boundary falls at the **Delta Lake ingestion point**. Everything upstream — PostgreSQL, TimescaleDB, the Kafka topics — operates in OLTP mode: writes are frequent, latency-sensitive, and row-oriented. PostgreSQL processes individual patient record updates; TimescaleDB absorbs thousands of vitals writes per minute. These systems are optimised for point lookups and short transactions.

The moment data lands in Delta Lake it crosses into the analytical domain. Nightly Airflow DAGs transform and load curated data into Snowflake, where it is never updated row-by-row — only read in large scans. The ML feature store also sits on the analytical side: features are computed in batch by Spark jobs and read during inference, not written transactionally. This clean separation prevents reporting queries from competing with live clinical workloads and allows each layer to be scaled independently.

## Trade-offs

The most significant trade-off is the **operational complexity of the Lambda architecture** — running parallel real-time (Kafka Streams) and batch (Spark) pipelines for overlapping data. The same business logic must be maintained in two places, and output discrepancies are inevitable during late-arriving data or incidents.

Mitigation is threefold. First, shared schema contracts and unit tests across both pipelines are enforced via a common library, reducing logic drift. Second, the batch layer is the authoritative source of truth; the streaming layer is explicitly labelled "near-real-time, subject to correction" in the clinician UI. Third, the architecture is structured so that adopting Apache Flink — which unifies stream and batch under one model — is a self-contained migration that leaves storage and the application layer untouched, giving the team a clear upgrade path if operational burden grows.
