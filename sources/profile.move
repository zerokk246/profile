/*
/// Module: profile
module profile::profile;
*/

module profile::profile {
    use std::string::String;
    use sui::table;
    use sui::table::Table;
    use sui::event::emit;

    const ErrNotProfileOwner: u64 = 1001;

    public struct Database has key {
        id: UID,
        profiles: Table<address, address>,
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

    public entry fun create_database(ctx: &mut TxContext) {
        let db = Database {
            id: object::new(ctx),
            profiles: table::new(ctx)
        };
        let database_id = object::uid_to_inner(&db.id);
        transfer::share_object(db);

        emit(EventCreateDatabase { database_id });
    }

    public entry fun create_profile(
        db: &mut Database,
        name: String,
        desc: String,
        avatar: String,
        ctx: &mut TxContext,
    ) {
        let sender_addr = ctx.sender();
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

    public entry fun update_profile(
        profile: &mut Profile,
    mut name: Option<String>,
    mut desc:Option<String>,
    mut avatar: Option<String>,
    ctx: &mut TxContext,
    ) {
    let sender_addr = ctx.sender();
    assert!(sender_addr == profile.owner_address, ErrNotProfileOwner);

    if (option::is_some<String>(& name)) {
    profile.name = option::extract( &mut name);
    };
    if (option::is_some<String>(&desc)) {
    profile.desc = option::extract( &mut desc);
    };
    if (option::is_some<String>(&name)) {
    profile.avatar = option::extract( &mut avatar);
    };
    }

    public entry fun delete_profile(
        db: &mut Database,
        profile: Profile,
        ctx: &mut TxContext,
    ) {
        let sender_addr = ctx.sender();
        assert!(sender_addr == profile.owner_address, ErrNotProfileOwner);

        table::remove(&mut db.profiles, sender_addr);
        drop(profile);
    }

    public fun drop(profile: Profile) {
        let Profile { id, name: _, desc: _, avatar: _, owner_address: _ } = profile;
        object::delete(id);
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