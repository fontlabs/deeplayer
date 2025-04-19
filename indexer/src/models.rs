use crate::schema::{coins, activities, operators, restakeds, rewards, services, stakers, withdrawals};
use diesel::prelude::*;

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = stakers)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Staker {
    pub id: String,
    pub delegated_to: String,
}

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = operators)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Operator {
    pub id: String,
    pub name: String,
    pub image: String,
    pub about: String,
    pub website: String,
}

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = coins)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Coin {
    pub id: String,
    pub coin_type: String,
    pub name: String,
    pub symbol: String,
    pub decimals: i32,
    pub image: String,
    pub about: String,
    pub website: String,
    pub category: String,
    pub total_value_restaked: i64,
}

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = restakeds)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Restaked {
    pub id: String,
    pub staker: String,
    pub coin: String,
    pub value: i64,
}

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = services)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Service {
    pub id: String,
    pub name: String,
    pub image: String,
    pub about: String,
    pub website: String,
    pub category: String,
}

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = rewards)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Reward {
    pub id: String,
    pub reward_root: String,
    pub coin: String,
    pub value: i64,
    pub service: String,
    pub start_timestamp_ms: i32,
    pub duration: i32
}

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = withdrawals)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Withdrawal {
    pub id: String,
    pub withdrawal_root: String,
    pub withdrawer: String,
    pub coins: vec[String],
    pub values: vec[i64],
    pub withdrawn_as_coins: bool,
    pub withdrawn_as_shares: bool,
    pub start_epoch: i32,
    pub min_withdrawal_delay: i32,
}

#[derive(Queryable, Selectable, Insertable, AsChangeset, Debug)]
#[diesel(table_name = activities)]
#[diesel(check_for_backend(diesel::pg::Pg))]
pub struct Activity {
    pub id: String,
    pub actor: String,
    pub action_type: String,
    pub coin: String,
    pub value: String,
    pub memo: String,
    pub timestamp_ms: String,
}