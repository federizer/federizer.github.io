-- ----------------------------
-- Table structure for attachment
-- ----------------------------
DROP TABLE IF EXISTS "public"."attachment";
CREATE TABLE "public"."attachment" (
"id" uuid NOT NULL,
"file_name" varchar(255) COLLATE "default" NOT NULL,
"mime_type" varchar(255) COLLATE "default" NOT NULL,
"uuaid" uuid NOT NULL,
"uufid" uuid NOT NULL,
"message_id" uuid NOT NULL,
"meta" jsonb
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Table structure for envelope
-- ----------------------------
DROP TABLE IF EXISTS "public"."envelope";
CREATE TABLE "public"."envelope" (
"id" uuid NOT NULL,
"uueid" uuid NOT NULL,
"message_id" uuid NOT NULL,
"recipient_id" uuid NOT NULL,
"meta" jsonb
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Table structure for envelope_label
-- ----------------------------
DROP TABLE IF EXISTS "public"."envelope_label";
CREATE TABLE "public"."envelope_label" (
"id" uuid NOT NULL,
"name" varchar(255) COLLATE "default" NOT NULL,
"envelope_id" uuid NOT NULL
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Table structure for envelope_properties
-- ----------------------------
DROP TABLE IF EXISTS "public"."envelope_properties";
CREATE TABLE "public"."envelope_properties" (
"id" uuid NOT NULL,
"meta" jsonb,
"rejected" bool DEFAULT false NOT NULL,
"starred" bool DEFAULT false NOT NULL,
"unread" bool DEFAULT true NOT NULL,
"envelope_id" uuid NOT NULL
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Table structure for identity
-- ----------------------------
DROP TABLE IF EXISTS "public"."identity";
CREATE TABLE "public"."identity" (
"id" uuid NOT NULL
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Table structure for message
-- ----------------------------
DROP TABLE IF EXISTS "public"."message";
CREATE TABLE "public"."message" (
"id" uuid NOT NULL,
"mime_type" varchar(255) COLLATE "default" NOT NULL,
"received" timestamp(6),
"sent" timestamp(6),
"subject" varchar(255) COLLATE "default",
"time_stamp" timestamp(6) NOT NULL,
"uufid" uuid NOT NULL,
"uumid" uuid NOT NULL,
"uupid" uuid,
"uurn" uuid NOT NULL,
"sender_id" uuid NOT NULL,
"meta" jsonb
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Table structure for message_properties
-- ----------------------------
DROP TABLE IF EXISTS "public"."message_properties";
CREATE TABLE "public"."message_properties" (
"id" uuid NOT NULL,
"created" timestamp(6) NOT NULL,
"modified" timestamp(6),
"message_id" uuid NOT NULL
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Table structure for principal
-- ----------------------------
DROP TABLE IF EXISTS "public"."principal";
CREATE TABLE "public"."principal" (
"id" uuid NOT NULL,
"uupn" varchar(255) COLLATE "default" NOT NULL,
"identity_id" uuid
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Alter Sequences Owned By 
-- ----------------------------

-- ----------------------------
-- Uniques structure for table attachment
-- ----------------------------
ALTER TABLE "public"."attachment" ADD UNIQUE ("uufid");

-- ----------------------------
-- Primary Key structure for table attachment
-- ----------------------------
ALTER TABLE "public"."attachment" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table envelope
-- ----------------------------
ALTER TABLE "public"."envelope" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table envelope_label
-- ----------------------------
ALTER TABLE "public"."envelope_label" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Uniques structure for table envelope_properties
-- ----------------------------
ALTER TABLE "public"."envelope_properties" ADD UNIQUE ("envelope_id");

-- ----------------------------
-- Primary Key structure for table envelope_properties
-- ----------------------------
ALTER TABLE "public"."envelope_properties" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Primary Key structure for table identity
-- ----------------------------
ALTER TABLE "public"."identity" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Uniques structure for table message
-- ----------------------------
ALTER TABLE "public"."message" ADD UNIQUE ("uufid");

-- ----------------------------
-- Primary Key structure for table message
-- ----------------------------
ALTER TABLE "public"."message" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Uniques structure for table message_properties
-- ----------------------------
ALTER TABLE "public"."message_properties" ADD UNIQUE ("message_id");

-- ----------------------------
-- Primary Key structure for table message_properties
-- ----------------------------
ALTER TABLE "public"."message_properties" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Uniques structure for table principal
-- ----------------------------
ALTER TABLE "public"."principal" ADD UNIQUE ("uupn");

-- ----------------------------
-- Primary Key structure for table principal
-- ----------------------------
ALTER TABLE "public"."principal" ADD PRIMARY KEY ("id");

-- ----------------------------
-- Foreign Key structure for table "public"."attachment"
-- ----------------------------
ALTER TABLE "public"."attachment" ADD FOREIGN KEY ("message_id") REFERENCES "public"."message" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."envelope"
-- ----------------------------
ALTER TABLE "public"."envelope" ADD FOREIGN KEY ("message_id") REFERENCES "public"."message" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;
ALTER TABLE "public"."envelope" ADD FOREIGN KEY ("recipient_id") REFERENCES "public"."principal" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."envelope_label"
-- ----------------------------
ALTER TABLE "public"."envelope_label" ADD FOREIGN KEY ("envelope_id") REFERENCES "public"."envelope" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."envelope_properties"
-- ----------------------------
ALTER TABLE "public"."envelope_properties" ADD FOREIGN KEY ("envelope_id") REFERENCES "public"."envelope" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."message"
-- ----------------------------
ALTER TABLE "public"."message" ADD FOREIGN KEY ("sender_id") REFERENCES "public"."principal" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."message_properties"
-- ----------------------------
ALTER TABLE "public"."message_properties" ADD FOREIGN KEY ("message_id") REFERENCES "public"."message" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."principal"
-- ----------------------------
ALTER TABLE "public"."principal" ADD FOREIGN KEY ("identity_id") REFERENCES "public"."identity" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;
