Recommendation: Data Lakehouse
A Data Lakehouse is the right architecture for this startup, and the reasoning follows directly from the nature of the four data types they are collecting.
Reason 1 — The data is fundamentally multi-format, and a Warehouse cannot hold most of it
A traditional Data Warehouse is built exclusively for structured, tabular data. Of the four data streams this startup collects, only one — payment transactions — is naturally structured. GPS logs are semi-structured time-series data, customer text reviews are unstructured free text, and restaurant menu images are raw binary files. A Warehouse would require all of these to be pre-processed and flattened into rows and columns before storage, which either destroys information (you cannot store an image in a SQL table meaningfully) or creates an expensive bottleneck where data waits to be transformed before it can be stored at all. A Lakehouse stores all four formats natively in open file formats (Parquet, JSON, JPEG, plain text) on cheap object storage, so nothing is discarded or delayed.
Reason 2 — A pure Data Lake lacks the governance and query performance the business needs
The obvious counter-argument is to use a Data Lake, which would handle the multi-format problem. But a fast-growing food delivery startup has pressing analytical needs — finance teams querying payment trends, operations dashboards tracking delivery times, product managers measuring review sentiment — that require reliable, fast SQL queries with consistent results. A raw Data Lake has no ACID transactions, no schema enforcement, and no indexing. Two analysts running the same query at the same time can get different results if a write is in progress. A Lakehouse adds a transactional metadata layer (Delta Lake, Apache Iceberg, or Apache Hudi) on top of the raw storage, giving the query reliability and consistency of a Warehouse without sacrificing the format flexibility of a Lake.
Reason 3 — GPS logs and images require ML pipelines that cannot run inside a Warehouse
The GPS location logs and menu images are not just storage problems — they are inputs to machine learning models. GPS sequences feed delivery time prediction and route optimisation models. Menu images feed computer vision pipelines that auto-tag cuisine types or flag menu updates. Customer reviews feed NLP models for sentiment analysis and complaint detection. These workloads require frameworks like PyTorch, TensorFlow, and Spark running directly against raw files. A Warehouse locks data inside a proprietary engine with no path to ML tooling. A Lakehouse keeps data in open formats on object storage, so the same files that serve a SQL analytics query can also be read directly by a training pipeline — with no copying, no export, and no duplication.
Reason 4 — The startup's scale trajectory makes cost architecture critical
"Fast-growing" means data volume is compounding. Warehouses charge for both storage and compute at premium rates, and costs scale aggressively as data grows. A Lakehouse separates storage (cheap object storage like S3 or GCS, costing a few dollars per terabyte per month) from compute (query engines like Trino, Spark, or DuckDB that are spun up on demand). GPS logs alone — one coordinate pair per second per active driver — will accumulate billions of rows within a year. Storing that in a Warehouse would be prohibitively expensive. Storing it as Parquet files on object storage and querying it with a decoupled engine keeps costs proportional to actual usage rather than to total data volume.
Summary
Criterion
Data Warehouse
Data Lake
Data Lakehouse
Stores images & raw text
✗
✓
✓
ACID transactions & SQL
✓
✗
✓
ML pipeline access
✗
✓
✓
Cost at scale
✗
✓
✓
Schema enforcement
✓
✗
✓
The Lakehouse is not a compromise between the other two — it is the architecture that was specifically designed for the situation this startup is in: diverse data types, mixed analytical and ML workloads, and a growth curve that makes cost and flexibility non-negotiable from day one.