### 1. teams
* **Intent:** Groups employees into bounded contexts, ensuring authorized personnel can collaborate, store, and access shared machine learning metadata within specific projects.
* **Security & Design:** Utilizes UUIDs for the primary key to prevent Insecure Direct Object Reference (IDOR) / enumeration attacks, protect tenant privacy, and guarantee global uniqueness across distributed environments.

### 2. users
* **Intent:** Represents individual application users responsible for storing and managing ML model metadata during training and testing loops.
* **Data Sourcing:** Profile attributes, specifically `avatar_url` and `name`, are populated and synchronized directly from the Google OAuth2 provider response.

### 3. team_members
* **Intent:** A junction table defining the many-to-many relationship mapping users to teams.
* **Access Control:** Defines specific authorization roles for users within a team context. (Note: Future scalability may require migrating this to dedicated `permissions` and `role_permissions` tables).
* **Indexing Strategy:** * Implements a composite primary key on `(team_id, user_id)` for standard forward lookups.
  * Includes a reverse index to ensure high-performance queries when retrieving all teams associated with a specific user.

### 4. auth_identities
* **Intent:** The foundational translation layer for the federated OAuth2 implementation.
* **Mapping:** Captures the external identity provider and the immutable, unique ID supplied by that provider.
* **Indexing Strategy:** Relies on unique constraints to implicitly generate the B-tree indexes required for rapid identity verification lookups on both `(provider, provider_id)` and `(user_id, provider)` pairs.

### 5. api_keys
* **Intent:** Enables headless authentication, allowing external scripting languages, CLI tools, and automated pipelines to securely interact with the service.
* **Security:** Maps the `user_id` to a one-way hash of the API key rather than storing the raw key.
* **Authorization:** Utilizes a `scopes` array to enforce granular access control (e.g., restricting whether a script can write metrics, create projects, or query model performance).
* **Lifecycle Management:** Token expiration is tracked via a `TIMESTAMPTZ` column.
* **Indexing Strategy:** A unique constraint on the `key_hash` column ensures implicit index creation for rapid authentication lookups.

### 6. model_projects
* **Intent:** Stores overarching machine learning projects assigned to specific teams.
* **Indexing Strategy:** Employs explicit indexes on `team_id` and `creator_id` to efficiently retrieve and filter projects tied to a given team or specific creator.

### 7. training_runs
* **Intent:** Records distinct model runs tied to specific projects.
* **Architecture Note:** This table explicitly *does not* contain the granular time-series metrics associated with a run. Instead, it aggregates top-level information and "best" scores for leaderboard ranking.
* **Data Flexibility:** Hyperparameters are stored in a `JSONB` column to allow flexible, schema-less key/value pairs for different model architectures.
* **Indexing Strategy:** Includes indexes on `project_id`, as well as composite indexes pairing `project_id` with specific "best metrics" to enable lightning-fast sorting.

### 8. metrics_log
* **Intent:** A write-heavy table strictly for logging high-frequency loss and accuracy metrics (train/test/validation loss, FID score) tied to a specific `training_runs` record.
* **Ordering Strategy (`step`):** Relies on a client-provided `step` integer rather than a `created_at` timestamp for proper ordering. This prevents race conditions where two rapid API calls receive the exact same timestamp, removing chance from the ordering logic.
* **Indexing Strategy:** A unique composite constraint on `(run_id, step)` implicitly generates the exact composite index required to efficiently fetch metrics for a given run and return them pre-sorted by timestep.