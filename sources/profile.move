module profile::profile {
    use std::string::String;
    use sui::table::{Self, Table};
    use sui::event::emit;
    use sui::package;
    use sui::display;
    use std::string::utf8;
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::{SUI};

    const ErrInvalidParam: u64 = 1000;
    const ErrNotProfileOwner: u64 = 1001;
    const ErrProfileAlreadyExists: u64 = 1002;
    const Fee: u64 = 1_000_000_000;


    public struct Database has key {
        id: UID,
        fee: Balance<SUI>,
        profiles: Table<address, address>,
    }

    public struct DataBaseCap has key {
        id: UID,
        `for`:ID,
    }

    public struct Profile has key, store {
        id: UID,
        name: String,
        desc: String,
        avatar: String,
        owner_address: address,
    }

    /* Events */

    public struct EventCreateDatabase has copy, drop {
        database_id: ID,
    }

    public struct EventCreateProfile has copy, drop {
        profile_id: ID,
        database_id: ID,
        owner_address: address,
    }

    /* Functions */

    fun init(otw: PROFILE, ctx: &mut TxContext) {
        let publisher = package::claim(otw, ctx);

        let mut display = display::new_with_fields<Profile>(
            &publisher,
            vector[
                utf8(b"name"),
                utf8(b"description"),
                utf8(b"avatar"),
                utf8(b"creator"),
            ], vector[
                utf8(b"{name}"),
                utf8(b"{desc}"), 
                utf8(b"{avatar}"), 
                utf8(b"Sui fan"),
            ], ctx
        );

        display::update_version(&mut display);

        transfer::public_transfer(publisher, ctx.sender());
        transfer::public_transfer(display, ctx.sender());
    }

    public entry fun create_database(ctx: &mut TxContext) {
        let db = Database {
            id: object::new(ctx),
            fee: balance::zero(),
            profiles: table::new(ctx)
        };

        let database_id = object::uid_to_inner(&db.id);

        let cap = DataBaseCap {
            id: object::new(ctx),
            `for`: database_id
        };

        transfer::transfer(cap, ctx.sender());


        let database_id = object::uid_to_inner(&db.id);
        transfer::share_object(db);

        emit(EventCreateDatabase { database_id });
    }

    public entry fun create_profile(
        db: &mut Database,
        name: String,
        desc: String,
        avatar: String,
        coin: &mut Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let sender_addr = ctx.sender();
        assert!(!db.profiles.contains(sender_addr), ErrProfileAlreadyExists);

        let fee = coin::split(coin, Fee, ctx);
        coin::put(&mut db.fee, fee);

        let profile = Profile {
            id: object::new(ctx),
            name,
            desc,
            avatar,
            owner_address: sender_addr,
        };

        let profile_addr = object::uid_to_address(&profile.id);
        let profile_id = object::uid_to_inner(&profile.id);

        table::add(&mut db.profiles, sender_addr, profile_addr);
        transfer::transfer(profile, sender_addr);

        emit(EventCreateProfile { database_id: object::id(db), profile_id, owner_address: sender_addr });
    }

    public entry fun get_profiles(
        db: &Database, 
        addresses: vector<address>, 
        _ctx: &mut TxContext
        ) : vector<address> {
            let len = vector::length(&addresses);
            assert!(len > 0, ErrInvalidParam);

            let mut results = vector::empty<address>();
            let mut i = 0;
            while ( i < len ) {
                let addr = *vector::borrow(&addresses, i);
                if (db.profiles.contains(addr)) {
                    let profile_addr = *table::borrow(&db.profiles, addr);
                    results.push_back(profile_addr);
                };

                i = i + 1;
            };

            return results
    }

    public entry fun update_profile(
        profile: &mut Profile,
        mut name: Option<String>,
        mut desc:Option<String>,
        mut avatar: Option<String>,
        ctx: &TxContext,
    ) {
        let sender_addr = ctx.sender();
        assert!(sender_addr == profile.owner_address, ErrNotProfileOwner);

        if (option::is_some<String>(& name)) {
            profile.name = option::extract( &mut name);
        };
        if (option::is_some<String>(&desc)) {
            profile.desc = option::extract( &mut desc);
        };
        if (option::is_some<String>(&avatar)) {
            profile.avatar = option::extract( &mut avatar);
        };
    }

    public entry fun delete_profile(
        db: &mut Database,
        profile: Profile,
        ctx: &TxContext,
    ) {
        let sender_addr = ctx.sender();
        assert!(sender_addr == profile.owner_address, ErrNotProfileOwner);

        table::remove(&mut db.profiles, sender_addr);
        drop(profile);
    }

    public fun withdraw(cap: &DataBaseCap, self: &mut Database, ctx: &mut TxContext) : Coin<SUI> {
        assert!(cap.`for` == object::id(self) , ErrInvalidParam);
        let balance = balance::withdraw_all(&mut self.fee);
        let coin = coin::from_balance(balance, ctx);
        coin
    }
    

    fun drop(profile: Profile) {
        let Profile { id, name: _, desc: _, avatar: _, owner_address: _ } = profile;
        object::delete(id);
    }

    public struct PROFILE has drop {}

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = PROFILE {};
        init(otw, ctx);
    }    

    #[test_only]
    public(package) fun get_profile_name(p: &Profile): String {
        p.name
    }

    #[test_only]
    public(package) fun get_profile_desc(p: &Profile): String {
        p.desc
    }

    #[test_only]
    public(package) fun get_profile_owner(p: &Profile): address {
        p.owner_address
    }

    #[test_only]
    public(package) fun get_database_profiles_len(d: &Database): u64 {
        table::length(&d.profiles)
    }
}