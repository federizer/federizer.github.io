CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.mtime = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS identity (
  guidentity varchar(255) NOT NULL,
  PRIMARY KEY (guidentity)
);

CREATE TABLE IF NOT EXISTS entity (
  owner varchar(255) NOT NULL,
  guid bytea NOT NULL,
  creator varchar(255) NOT NULL,
  entity_parent_guid bytea,
  ctime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mtime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  perms int DEFAULT '500',
  type int DEFAULT '0',
  subtype int DEFAULT '0',
  locked smallint DEFAULT 0,
  hidden smallint DEFAULT 0,
  refnum_guid bytea,
  refnum varchar(255),
  PRIMARY KEY (owner, guid),
  CONSTRAINT fk_entity_owner FOREIGN KEY (owner) REFERENCES identity(guidentity),
  CONSTRAINT fk_entity_creator FOREIGN KEY (creator) REFERENCES identity(guidentity),
  CONSTRAINT fk_entity_entity_parent_owner_guid FOREIGN KEY (owner, entity_parent_guid) REFERENCES entity(owner, guid)
);

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON entity
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE TABLE IF NOT EXISTS entity_content (
  owner varchar(255) NOT NULL,
  guid bytea NOT NULL,
  creator varchar(255) NOT NULL,
  entity_guid bytea NOT NULL,
  ctime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mtime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mime_type varchar(50) NOT NULL DEFAULT 'application/octet-stream',
  size bigint NOT NULL DEFAULT 0,
  meta varchar(1000) default '{}',
  sha1 bytea DEFAULT NULL,
  PRIMARY KEY (owner, guid),
  CONSTRAINT fk_entity_content_owner FOREIGN KEY (owner) REFERENCES identity(guidentity),
  CONSTRAINT fk_entity_content_creator FOREIGN KEY (creator) REFERENCES identity(guidentity),
  CONSTRAINT fk_entity_content_entity_owner_guid FOREIGN KEY (owner, entity_guid) REFERENCES entity(owner, guid)
);

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON entity_content
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE TABLE IF NOT EXISTS link (
  owner varchar(255) NOT NULL,
  guid bytea NOT NULL,
  creator varchar(255) NOT NULL,
  entity_guid bytea NOT NULL,
  entity_parent_guid bytea,
  ctime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mtime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  name varchar(1000),
  unread smallint DEFAULT 0,
  starred smallint DEFAULT 0,
  PRIMARY KEY (owner, guid),
  CONSTRAINT fk_link_owner FOREIGN KEY (owner) REFERENCES identity(guidentity),
  CONSTRAINT fk_link_creator FOREIGN KEY (creator) REFERENCES identity(guidentity),
  CONSTRAINT fk_link_entity_owner_guid FOREIGN KEY (owner, entity_guid) REFERENCES entity(owner, guid),
  CONSTRAINT fk_link_entity_parent_owner_guid FOREIGN KEY (owner, entity_parent_guid) REFERENCES entity(owner, guid)
);

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON link
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();

CREATE TABLE IF NOT EXISTS access (
  owner varchar(255) NOT NULL,
  guid bytea NOT NULL,
  guidentity varchar(255) NOT NULL,
  link_guid bytea NOT NULL,
  entity_content_guid bytea NOT NULL,
  ctime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  mtime TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  perms int DEFAULT '500',
  keygen_meta varchar(255),  
  PRIMARY KEY (owner, guid),
  CONSTRAINT fk_access_owner FOREIGN KEY (owner) REFERENCES identity(guidentity),
  CONSTRAINT fk_access_guidentity FOREIGN KEY (guidentity) REFERENCES identity(guidentity),
  CONSTRAINT fk_access_link_owner_guid FOREIGN KEY (owner, link_guid) REFERENCES link(owner, guid),
  CONSTRAINT fk_access_entity_content_owner_guid FOREIGN KEY (owner, entity_content_guid) REFERENCES entity_content(owner, guid)
);

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON access
FOR EACH ROW
EXECUTE PROCEDURE trigger_set_timestamp();


