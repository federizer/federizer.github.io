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
-- Records of attachment
-- ----------------------------
INSERT INTO "public"."attachment" VALUES ('23f4322a-904b-4ad8-aee1-e74fb865e0d0', 'Hlinkovo-nam-cac-1930-1.jpg', 'image/jpeg', 'f9c43e30-5a5c-4a74-b879-06451ff07528', 'b818f7f5-db57-48de-b42f-a326bd579d3c', '8830d88f-58ea-4b8e-9138-291a462eacba', null);
INSERT INTO "public"."attachment" VALUES ('9f2d2497-f5b5-4312-ab8b-38ec1e7302f5', 'Hlinkovo-nam-cac-1930-1.jpg', 'image/jpeg', 'e17dca89-1f66-4628-9203-e02aad4e539a', 'fa5d8f81-56a5-4beb-b30c-8d04025e3742', '8830d88f-58ea-4b8e-9138-291a462eacba', null);

-- ----------------------------
-- Table structure for envelope
-- ----------------------------
DROP TABLE IF EXISTS "public"."envelope";
CREATE TABLE "public"."envelope" (
"id" uuid NOT NULL,
"meta" jsonb,
"uueid" uuid NOT NULL,
"message_id" uuid NOT NULL,
"recipient_id" uuid NOT NULL
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Records of envelope
-- ----------------------------

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
-- Records of envelope_label
-- ----------------------------

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
-- Records of envelope_properties
-- ----------------------------

-- ----------------------------
-- Table structure for identity
-- ----------------------------
DROP TABLE IF EXISTS "public"."identity";
CREATE TABLE "public"."identity" (
"id" uuid NOT NULL,
"upn" varchar(255) COLLATE "default" NOT NULL
)
WITH (OIDS=FALSE)

;

-- ----------------------------
-- Records of identity
-- ----------------------------
INSERT INTO "public"."identity" VALUES ('1b55ae52-b66f-4ccf-81a1-fba373ba7845', 'izboran@gmail.com');
INSERT INTO "public"."identity" VALUES ('be3351e6-5fe5-4b57-a7f7-3482b00d5066', 'izboran7@gmail.com');

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
-- Records of message
-- ----------------------------
INSERT INTO "public"."message" VALUES ('8830d88f-58ea-4b8e-9138-291a462eacba', 'text/plain;charset=us-ascii', null, '2018-05-02 11:49:54.255', 'Salute', '2018-05-02 11:48:01.066', '8d2b42e7-b9f3-4767-add6-25d4b9098edf', '0362f35d-72dd-489d-aef2-3599c5121cc7', null, '05421960-d362-4e73-93fc-e0347c085a80', '1b55ae52-b66f-4ccf-81a1-fba373ba7845', null);
INSERT INTO "public"."message" VALUES ('a9cdf75c-2efc-450a-9554-a11a80b7fca6', 'text/plain;charset=us-ascii', null, null, 'Greetings', '2018-05-02 20:45:50.245', 'aa47d9c0-1d2a-40b3-9bd3-7594dc1d35bc', 'a29c38b2-e0f8-4dfb-8fba-5467d1498ba5', null, 'bccba04a-648a-4615-b699-63a90698d1ec', '1b55ae52-b66f-4ccf-81a1-fba373ba7845', null);

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
-- Records of message_properties
-- ----------------------------

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
-- Uniques structure for table identity
-- ----------------------------
ALTER TABLE "public"."identity" ADD UNIQUE ("upn");

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
-- Foreign Key structure for table "public"."attachment"
-- ----------------------------
ALTER TABLE "public"."attachment" ADD FOREIGN KEY ("message_id") REFERENCES "public"."message" ("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."envelope"
-- ----------------------------
ALTER TABLE "public"."envelope" ADD FOREIGN KEY ("recipient_id") REFERENCES "public"."identity" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;
ALTER TABLE "public"."envelope" ADD FOREIGN KEY ("message_id") REFERENCES "public"."message" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

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
ALTER TABLE "public"."message" ADD FOREIGN KEY ("sender_id") REFERENCES "public"."identity" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Key structure for table "public"."message_properties"
-- ----------------------------
ALTER TABLE "public"."message_properties" ADD FOREIGN KEY ("message_id") REFERENCES "public"."message" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION;
