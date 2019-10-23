create table "issue" (
    "number" decimal(16,0)
  , "id" decimal(16,0) not null primary key
  , "user_id" decimal(16,0)
  , "user_login" varchar(255)
  , "user_gravatar_id" varchar(255)
  , "user_avatar_url" varchar(255)
  , "state" varchar(255)
  , "comments_url"  varchar(1024)
  , "labels_url"  varchar(1024)
  , "comments"  decimal(16,0)
  , "repository_url"  varchar(1024)
  , "events_url"  varchar(1024)
  , "assignee"  varchar(255)
  , "author_association"  varchar(255)
  , "url"  varchar(1024)
  , "created_at"  datetime not null
  , "updated_at"  datetime
  , "closed_at"   datetime
  , "milestone"  varchar(255)
  , "title"  varchar(255)
  , "node_id"  varchar(255)
  , "locked"  varchar(1)
  , "body" varchar(16384)
  , "html_url" varchar(1024)
  , "labels" varchar(16384)
  , "assignees" varchar(16384)
);

create table "comment" (
    "id" decimal(16,0) not null primary key
   ,"author_association" varchar(255)
   ,"body" varchar(16384)
   ,"created_at" datetime not null
   ,"html_url" varchar(1024)
   ,"issue_url" varchar(1024)
   ,"node_id" varchar(255)
   ,"updated_at" datetime
   ,"url" varchar(1024)
   ,"user" varchar(16384)
);
