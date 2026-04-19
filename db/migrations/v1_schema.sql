CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- teams for grouping users together for ML projects
CREATE TABLE teams (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- details about application users
CREATE TABLE users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- maps oath identity to 
CREATE TABLE auth_identities (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_id TEXT NOT NULL, --unique identifier given by provider
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (provider, provider_id),
    UNIQUE (user_id, provider)
);
-- unique constraints create the b trees we need for indexing purposes

-- allows headless scripts to authenticate without a browser
CREATE TABLE api_keys (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash TEXT NOT NULL UNIQUE, 
    name TEXT NOT NULL,
    scopes TEXT[],
    expires_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX idx_api_keys_expires_at ON api_keys(expires_at);

-- maps members to given teams
CREATE TABLE team_members (
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('ADMIN', 'MEMBER')) NOT NULL,
    PRIMARY KEY (team_id, user_id)
);
-- reverse composite for finding all teams a user is a part of
CREATE INDEX idx_team_members_user_team ON team_members(user_id, team_id);

-- details for ML project for a given team
CREATE TABLE model_projects (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    team_id UUID  NOT NULL references teams(id) ON DELETE CASCADE,
    creator_id UUID references users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description text,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_model_projects_team_id ON model_projects(team_id);
CREATE INDEX idx_model_projects_creator_id ON model_projects(creator_id);


-- within a project, can store analytical data for full training runs (each row is tied to a group of metrics)
create TABLE training_runs (
    id UUID default uuid_generate_v4() PRIMARY KEY,
    project_id UUID NOT NULL references model_projects(id) ON DELETE CASCADE,
    model_type TEXT NOT NULL,
    status TEXT CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED')) DEFAULT 'PENDING',
    hyperparameters JSONB NOT NULL,
    best_fid_score DOUBLE PRECISION,
    best_val_loss DOUBLE PRECISION,
    best_train_loss DOUBLE PRECISION,
    best_test_loss DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_training_runs_project_id ON training_runs(project_id);
CREATE INDEX idx_runs_project_fid ON training_runs (project_id, best_fid_score ASC NULLS LAST);
CREATE INDEX idx_runs_project_val_loss ON training_runs (project_id, best_val_loss ASC NULLS LAST);
CREATE INDEX idx_runs_project_train_loss ON training_runs (project_id, best_train_loss ASC NULLS LAST);
CREATE INDEX idx_runs_project_test_loss ON training_runs (project_id, best_test_loss ASC NULLS LAST);
CREATE INDEX idx_training_runs_hyperparams ON training_runs USING GIN (hyperparameters);

-- within each trainng run, metrics like training loss, test loss, etc get stored here
CREATE TABLE metrics_log (
    id BIGSERIAL PRIMARY KEY,
    run_id UUID NOT NULL REFERENCES training_runs(id) ON DELETE CASCADE,
    step INT NOT NULL,
    training_loss DOUBLE PRECISION,
    test_loss DOUBLE PRECISION,
    validation_loss DOUBLE PRECISION,
    fid_score DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (run_id, step)
);