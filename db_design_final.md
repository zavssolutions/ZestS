# Database Design

## Table: user_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| user_id | UUID/RANDOM |  |
| mobile_no | VARCHAR(20) |  |
| first_name | VARCHAR(50) |  |
| last_name | VARCHAR(50) |  |
| dob | Date |  |
| gender | ENUM |  |
| location_preference | VARCHAR(50) |  |
| interested_in | ENUM/ARRAY |  |
| Class | ENUM |  |
| school_name | VARCHAR(50) | empty |
| address | TEXT |  |
| password_hash | TEXT |  |
| email | VARCHAR(255) |  |
| created_at | TIMESTAMPTZ |  |
| last_login | TIMESTAMPTZ |  |
| updated_at | TIMESTAMPTZ |  |
| role | ENUM |  |
| is_active | BOOLEAN |  |
| is_verified | BOOLEAN |  |
| profile_picture_url | VARCHAR(100) |  |
| country | VARCHAR(100) |  |
| state | VARCHAR(100) |  |
| interested_in | JSONB |  |
| paid | Boolean |  |
| aadhaar | VARCHAR(100) |  |
| image_url | VARCHAR(100) |  |
| other_urls | JSONBLOB |  |
| school_id/organizer_id |  |  |
| CITY | ENUM |  |
| google_UID | VARCHAR(100) |  |
| parent_id | FK |  |

## Table: parent_athelete_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| parent_uid | FK |  |
| athelete_ids | ARRAY/FK |  |
| CITY | ENUM |  |

## Table: skater_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| other_ids | JSONBLOB |  |
| category | ENUM/ARRAY |  |
| preferred_tracks | ENUM/ARRAY |  |
| club_name | VARCHAR(50) | autofill |
| trainer_name_mobile_no | ARRAY/VARCHAR(50) | autofill |
| skill_level | ENUM |  |
| years_skating | SMALLINT |  |
| school_name | VARCHAR(50) |  |
| Class | ENUM |  |
| images_url | JSONBLOB |  |
| other_urls | JSONBLOB |  |
| CITY | ENUM |  |

## Table: trainer_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| trainer_id | SERIAL |  |
| user_id | UUID |  |
| school_name | VARCHAR(100) |  |
| club_name | VARCHAR(100) |  |
| memberships | ENUM/ARRAY |  |
| specialization | ENUM/ARRAY |  |
| experience_years | SMALLINT |  |
| certifications | VARCHAR(100) |  |
| images_url | JSONBLOB |  |
| other_urls | JSONBLOB |  |
| trainer_name_mobile_no | GENERATED |  |
| CITY | ENUM |  |

## Table: organizer_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| organizer_id | SERIAL |  |
| user_id | UUID |  |
| org_name | VARCHAR(100) |  |
| website_url | VARCHAR(255) |  |
| is_verified_org | BOOLEAN |  |
| CITY | ENUM |  |

## Table: events_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| event_id | UUID |  |
| organizer_id | FK |  |
| title | VARCHAR(200) |  |
| description | TEXT |  |
| start_date | TIMESTAMPTZ |  |
| end_date | TIMESTAMPTZ |  |
| location_name | VARCHAR(100) |  |
| location_lat_long | POINT |  |
| venue_city | VARCHAR(20) |  |
| images_url | JSONBLOB |  |
| other_urls | JSONBLOB |  |
| CITY | ENUM |  |

## Table: event_categories_tbl 

| Field | Type | Default |
| :--- | :--- | :--- |
| category_id | SERIAL |  |
| event_id | FK |  |
| skate_type | ENUM/ARRAY |  |
| age_group | ENUM/ARRAY |  |
| track_type | ENUM/ARRAY |  |
| distance | VARCHAR(20) |  |
| price | DECIMAL(10,2) |  |
| gender_restriction | ENUM/ARRAY |  |
| max_slots | INT |  |
| images_url | JSONBLOB |  |
| other_urls | JSONBLOB |  |
| CITY | ENUM |  |

## Table: event_registrations_tbl 

| Field | Type | Default |
| :--- | :--- | :--- |
| registration_id | UUID |  |
| event_id | UUID |  |
| category_id | FK |  |
| user_id | FK |  |
| payment_id | VARCHAR(100) |  |
| status | ENUM/ARRAY |  |
| from_city | ENUM |  |
| CITY | ENUM |  |

## Table: event_results_tbl 

| Field | Type | Default |
| :--- | :--- | :--- |
| result_id | SERIAL |  |
| event_id | FK |  |
| category_id | FK |  |
| user_id | UUID | optional |
| rank | SMALLINT  |  |
| timing | INTERVAL  |  |
| points_earned | INT  |  |
| trainer_name_mobile_no | FK |  |
| CITY | ENUM |  |

## Table: notification_sent_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| notification_id | SERIAL |  |
| user_id | UUID |  |
| event_id | UUID |  |
| type | VARCHAR(50) |  |
| message | VARCHAR(300) |  |
| is_read | BOOLEAN |  |
| created_at | TIMESTAMPTZ |  |
| CITY | ENUM |  |

## Table: payments_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| payment_id  | UUID |  |
| user_id  | FK |  |
| event_id | FK |  |
| category_id | FK |  |
| amount  | DECIMAL(10,2) |  |
| payment_method  | ENUM/ARRAY |  |
| status  | ENUM/ARRAY |  |
| paid_at | TIMESTAMPTZ |  |
| transaction_id  | VARCHAR(50) |  |
| CITY | ENUM |  |

## Table: events_stats_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| event_id |  |  |
| category_id |  |  |
| view_count |  |  |
| attended_count |  |  |
| CITY | ENUM |  |

## Table: event_referral_tbl

| Field | Type | Default |
| :--- | :--- | :--- |
| event_id |  |  |
| category_id |  |  |
| referrer_user_id |  |  |
| referred_user_id |  |  |
| referral_points |  |  |
| CITY | ENUM |  |

## Table: event_participants_tbl 

| Field | Type | Default |
| :--- | :--- | :--- |
| participant_id | SERIAL |  |
| event_id | UUID |  |
| category_id | FK |  |
| user_id | FK | optional |
| payment_id | VARCHAR(100) | optional |
| status | ENUM/ARRAY | attended/ |
| CITY | ENUM |  |

# Additional Table Schemas

## Table: advertisers

```sql
advertisers (
id              UUID PRIMARY KEY,
user_id         UUID REFERENCES users(id),
company_name    VARCHAR(200),
website         VARCHAR(300),
is_approved     BOOLEAN DEFAULT FALSE
)
```

## Table: ad_campaigns

```sql
ad_campaigns (
id              UUID PRIMARY KEY,
advertiser_id   UUID REFERENCES advertisers(id),
name            VARCHAR(200),
budget          DECIMAL(10,2),
spent           DECIMAL(10,2) DEFAULT 0,
start_date      DATE,
end_date        DATE,
target_sports   INTEGER[],
target_locations TEXT[],
status          ENUM('draft', 'active', 'paused', 'completed')
)
```

## Table: ad_creatives

```sql
ad_creatives (
id              UUID PRIMARY KEY,
campaign_id     UUID REFERENCES ad_campaigns(id),
type            ENUM('image', 'video', 'text'),
media_url       VARCHAR(500),
click_url       VARCHAR(500),
cta_text        VARCHAR(50)
)
```

## Table: ad_impressions

```sql
ad_impressions (
id              UUID PRIMARY KEY,
creative_id     UUID REFERENCES ad_creatives(id),
user_id         UUID REFERENCES users(id),
event           ENUM('impression', 'click', 'conversion'),
created_at      TIMESTAMP DEFAULT NOW()
)
```

## Table: banners

```sql
banners (
id              UUID PRIMARY KEY,
title           VARCHAR(200),
image_url       VARCHAR(500) NOT NULL,
link_url        VARCHAR(500),
placement       ENUM('home_top', 'home_bottom', 'event_detail', 'search'),
display_order   INTEGER DEFAULT 0,
is_active       BOOLEAN DEFAULT TRUE,
start_date      TIMESTAMP,
end_date        TIMESTAMP,
created_at      TIMESTAMP DEFAULT NOW()
)
```

## Table: notification_templates

```sql
notification_templates (
id          UUID PRIMARY KEY,
key         VARCHAR(100) UNIQUE,
title       VARCHAR(200),
body        TEXT,
channel     ENUM('push', 'email', 'sms', 'in_app')
)
```

## Table: notifications

```sql
notifications (
id              UUID PRIMARY KEY,
user_id         UUID REFERENCES users(id),
template_id     UUID REFERENCES notification_templates(id),
title           VARCHAR(200),
body            TEXT,
is_read         BOOLEAN DEFAULT FALSE,
data            JSONB,
created_at      TIMESTAMP DEFAULT NOW()
)
```

## Table: notification_preferences

```sql
notification_preferences (
user_id             UUID REFERENCES users(id),
push_enabled        BOOLEAN DEFAULT TRUE,
email_enabled       BOOLEAN DEFAULT TRUE,
sms_enabled         BOOLEAN DEFAULT FALSE,
event_reminders     BOOLEAN DEFAULT TRUE,
marketing           BOOLEAN DEFAULT FALSE
)
```

## Table: device_tokens

```sql
device_tokens (
id          UUID PRIMARY KEY,
user_id     UUID REFERENCES users(id),
token       VARCHAR(500) NOT NULL,
platform    ENUM('ios', 'android'),
created_at  TIMESTAMP DEFAULT NOW()
)
```

## Table: reviews

```sql
reviews (
id          UUID PRIMARY KEY,
event_id    UUID REFERENCES events(id),
user_id     UUID REFERENCES users(id),
rating      INTEGER CHECK (rating BETWEEN 1 AND 5),
comment     TEXT,
created_at  TIMESTAMP DEFAULT NOW()
)
```

## Table: audit_logs

```sql
audit_logs (
id          UUID PRIMARY KEY,
user_id     UUID REFERENCES users(id),
action      VARCHAR(100),
entity_type VARCHAR(50),
entity_id   UUID,
metadata    JSONB,
ip_address  INET,
created_at  TIMESTAMP DEFAULT NOW()
)
```

