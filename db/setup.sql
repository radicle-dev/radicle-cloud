-- SPDX-License-Identifier: Apache-2.0

CREATE TYPE DEPLOYMENT_STATUS AS ENUM (
    'initial', 'allocated', 'setup-failed', 'running'
);

CREATE TABLE IF NOT EXISTS deployments (
    id BIGSERIAL PRIMARY KEY,
    org VARCHAR(42) NOT NULL UNIQUE,
    expiry NUMERIC NOT NULL,
    provider VARCHAR(20) NOT NULL DEFAULT '',
    ip INET,
    status DEPLOYMENT_STATUS NOT NULL DEFAULT 'initial'
);

CREATE INDEX ON deployments(org);

--

CREATE TYPE EVENT_TYPE AS ENUM (
    'NewTopUp', 'DeploymentStopped'
);

CREATE TABLE IF NOT EXISTS events (
    id BIGSERIAL PRIMARY KEY,
    type EVENT_TYPE NOT NULL,
    blockAndTx BYTEA NOT NULL UNIQUE,
    org VARCHAR(42) NOT NULL,
    emittedAt NUMERIC NOT NULL,
    expiry NUMERIC NOT NULL,
    processed BOOLEAN DEFAULT FALSE,
    removed BOOLEAN DEFAULT FALSE
);

CREATE INDEX ON events(org);
CREATE INDEX ON events(emittedAt);
