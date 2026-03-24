# Database Design (Synchronized with SQLModels)

## Table: users

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| parent_id | UUID | FK to users.id (for child accounts) |
| role | VARCHAR(20) | parent, kid, trainer, organizer, admin, sponsor, skater |
| sport | VARCHAR(20) | Default: skating |
| gender | VARCHAR(20) | male, female, other, unspecified |
| firebase_uid | VARCHAR(128) | Unique |
| google_uid | VARCHAR(128) | |
| mobile_no | VARCHAR(20) | Unique |
| email | VARCHAR(255) | Unique |
| first_name | VARCHAR(50) | |
| last_name | VARCHAR(50) | |
| dob | DATE | |
| country | VARCHAR(100) | |
| state | VARCHAR(100) | |
| city | VARCHAR(100) | |
| address | TEXT | |
| profile_picture_url | VARCHAR(500) | |
| is_active | BOOLEAN | |
| is_verified | BOOLEAN | |
| has_completed_profile | BOOLEAN | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| last_login_at | TIMESTAMPTZ | |

## Table: skater_profiles

| Field | Type | Description |
| :--- | :--- | :--- |
| user_id | UUID | PK, FK to users.id |
| skill_level | VARCHAR(50) | |
| years_skating | INT | |
| preferred_tracks | VARCHAR(255) | |
| school_name | VARCHAR(100) | |

## Table: trainer_profiles

| Field | Type | Description |
| :--- | :--- | :--- |
| user_id | UUID | PK, FK to users.id |
| school_name | VARCHAR(100) | |
| club_name | VARCHAR(100) | |
| specialization | TEXT | |
| experience_years | INT | |

## Table: organizer_profiles

| Field | Type | Description |
| :--- | :--- | :--- |
| user_id | UUID | PK, FK to users.id |
| org_name | VARCHAR(120) | |
| website_url | VARCHAR(255) | |
| is_verified_org | BOOLEAN | |

## Table: events

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| organizer_user_id | UUID | FK to users.id |
| title | VARCHAR(200) | |
| description | TEXT | |
| start_at_utc | TIMESTAMPTZ | |
| end_at_utc | TIMESTAMPTZ | |
| location_name | VARCHAR(120) | |
| venue_city | VARCHAR(100) | |
| latitude | FLOAT | |
| longitude | FLOAT | |
| banner_image_url | VARCHAR(500) | |
| status | VARCHAR(20) | draft, published, canceled, completed |

## Table: event_categories

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| event_id | UUID | FK to events.id |
| name | VARCHAR(120) | |
| skate_type | VARCHAR(60) | |
| age_group | VARCHAR(60) | |
| track_type | VARCHAR(60) | |
| distance | VARCHAR(30) | |
| gender_restriction| VARCHAR(30) | |
| max_slots | INT | |
| price | NUMERIC(10,2) | |

## Table: event_registrations

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| event_id | UUID | FK to events.id |
| category_id | UUID | FK to event_categories.id |
| user_id | UUID | FK to users.id |
| payment_id | UUID | FK to payments.id |
| status | VARCHAR(20) | pending, confirmed, canceled |
| from_city | VARCHAR(100) | |

## Table: event_results

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| event_id | UUID | FK to events.id |
| category_id | UUID | FK to event_categories.id |
| user_id | UUID | FK to users.id |
| rank | INT | |
| timing_ms | INT | |
| points_earned | INT | |

## Table: payments

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| user_id | UUID | FK to users.id |
| event_id | UUID | FK to events.id |
| category_id | UUID | FK to event_categories.id |
| provider | VARCHAR(30) | |
| amount | NUMERIC(10,2) | |
| currency | VARCHAR(3) | |
| status | VARCHAR(20) | initiated, success, failed, refunded |
| external_transaction_id | VARCHAR(100) | |
| paid_at | TIMESTAMPTZ | |

## Table: banners

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| title | VARCHAR(200) | |
| image_url | VARCHAR(500) | |
| link_url | VARCHAR(500) | |
| share_url | VARCHAR(500) | |
| placement | VARCHAR(50) | |
| display_order | INT | |
| is_active | BOOLEAN | |

## Table: device_tokens

| Field | Type | Description |
| :--- | :--- | :--- |
| id | UUID | Primary Key |
| user_id | UUID | FK to users.id |
| token | VARCHAR(500) | |
| platform | VARCHAR(20) | |
| created_at | TIMESTAMPTZ | |
