#[test_only]
module profile::profile_tests { 
    use std::string::utf8;
    use std::string::String;
    use sui::test_scenario::{Self};
    use profile::profile::{Self, Database, Profile};
    use sui::coin::{mint_for_testing};
    use sui::sui::{SUI};

    use profile::helpers::init_test_helper;

    public fun init_database_and_profile(scenario: &mut test_scenario::Scenario) {

        test_scenario::next_tx(scenario, @0x1);
        {
            let mut database = test_scenario::take_shared<Database>(scenario);
            let mut coin_ = mint_for_testing<SUI>(1_000_000_000, test_scenario::ctx(scenario));

            let ctx = test_scenario::ctx(scenario);
            // create profile
            profile::create_profile(
                &mut database,
                std::string::utf8(b"test"),
                std::string::utf8(b"desc..."),
                std::string::utf8(
                    b"https://www.google.com/images/branding/googlelogo/2x/googlelogo_light_color_272x92dp.png"
                ),
                &mut coin_,
                ctx,
            );
            transfer::public_transfer(coin_,@0x1);
            test_scenario::return_shared(database);
        };
    }

    #[test]
    fun test_profile() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        profile::create_database(test_scenario::ctx(scenario));


        init_database_and_profile(scenario);

        test_scenario::next_tx(scenario, @0x1);
        {
            let mut profile = test_scenario::take_from_sender<Profile>(scenario);
            // std::debug::print(&profile);
            assert!(profile::get_profile_name(&profile) == utf8(b"test"));

            let ctx = test_scenario::ctx(scenario);
            profile::update_profile(
                &mut profile,
                option::some(utf8(b"test2")),
                option::none<String>(),
                option::none<String>(),
                ctx);

            test_scenario::return_to_sender(scenario, profile);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let profile = test_scenario::take_from_sender<Profile>(scenario);
            // std::debug::print(&profile);
            // changed
            assert!(profile::get_profile_name(&profile) == utf8(b"test2"));
            // no change
            assert!(profile::get_profile_desc(&profile) == utf8(b"desc..."));
            test_scenario::return_to_sender(scenario, profile);
        };


        test_scenario::end(scenario_test);
    }

    #[test]
    fun test_get_profiles() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        profile::create_database(test_scenario::ctx(scenario));

        init_database_and_profile(scenario);

        test_scenario::next_tx(scenario, @0x1);
        {
            let mut database = test_scenario::take_shared<Database>(scenario);
            let mut ctx = tx_context::new_from_hint(@0x2, 0,0,0,0);
            let mut coin_ = mint_for_testing<SUI>(1_000_000_000, &mut ctx);

            // create profile
            profile::create_profile(
                &mut database,
                std::string::utf8(b"test2"),
                std::string::utf8(b"desc2..."),
                std::string::utf8(
                    b"https://www.google.com/images/branding/googlelogo/2x/googlelogo_light_color_272x92dp.png"
                ),
                &mut coin_,
                &mut ctx,
            );

            transfer::public_transfer(coin_,@0x1);
            test_scenario::return_shared(database);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let database = test_scenario::take_shared<Database>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let mut addresses = vector::empty<address>();
            addresses.push_back(@0x1);
            let _profiles = profile::get_profiles(&database, addresses,  ctx);
            assert!(_profiles.length() == 1, 1);

            addresses.push_back(@0x2);
            let _profiles = profile::get_profiles(&database, addresses,  ctx);
            assert!(_profiles.length() == 2, 1);

            test_scenario::return_shared(database);
        };

        test_scenario::end(scenario_test);
    }

    #[test, expected_failure(abort_code = ::sui::test_scenario::EEmptyInventory)]
    fun test_delete_profile() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        profile::create_database(test_scenario::ctx(scenario));

        init_database_and_profile(scenario);

        test_scenario::next_tx(scenario, @0x1);
        {
            let profile = test_scenario::take_from_sender<Profile>(scenario);
            // std::debug::print(&profile);
            assert!(profile::get_profile_name(&profile) == utf8(b"test"));
            test_scenario::return_to_sender(scenario, profile);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let profile = test_scenario::take_from_sender<Profile>(scenario);
            let mut database = test_scenario::take_shared<Database>(scenario);

            assert!(profile::get_database_profiles_len(&database) == 1, 1);

            let ctx = test_scenario::ctx(scenario);
            profile::delete_profile(&mut database, profile, ctx);

            assert!(profile::get_database_profiles_len(&database) == 0, 1);

            // test_scenario::return_to_sender(scenario, profile);
            test_scenario::return_shared(database);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let database = test_scenario::take_shared<Database>(scenario);
            assert!(profile::get_database_profiles_len(&database) == 0, 1);
            test_scenario::return_shared(database);

            // should abort EEmptyInventory
            let profile = test_scenario::take_from_sender<Profile>(scenario);
            test_scenario::return_to_sender(scenario, profile);
        };

        test_scenario::end(scenario_test);
    }

    #[test, expected_failure(abort_code = ::profile::profile::ErrNotProfileOwner)]
    fun test_check_owner_in_updating_profile() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        profile::create_database(test_scenario::ctx(scenario));

        init_database_and_profile(scenario);

        test_scenario::next_tx(scenario, @0x1);
        {
            let profile = test_scenario::take_from_sender<Profile>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let sender_addr = ctx.sender();

            assert!(profile::get_profile_name(&profile) == utf8(b"test"));
            assert!(profile::get_profile_owner(&profile) == sender_addr);

            test_scenario::return_to_sender(scenario, profile);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let mut profile = test_scenario::take_from_sender<Profile>(scenario);

            // change sender
            let ctx = tx_context::dummy();
            assert!(profile::get_profile_owner(&profile) != ctx.sender());

            // should abort
            profile::update_profile(
                &mut profile,
                option::some(utf8(b"test2")),
                option::none<String>(),
                option::none<String>(),
                &ctx);

            test_scenario::return_to_sender(scenario, profile);
        };


        test_scenario::end(scenario_test);
    }

    #[test, expected_failure(abort_code = ::profile::profile::ErrNotProfileOwner)]
    fun test_check_owner_in_deleting_profile() {
        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        profile::create_database(test_scenario::ctx(scenario));

        init_database_and_profile(scenario);

        test_scenario::next_tx(scenario, @0x1);
        {
            let profile = test_scenario::take_from_sender<Profile>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let sender_addr = ctx.sender();

            assert!(profile::get_profile_name(&profile) == utf8(b"test"));
            assert!(profile::get_profile_owner(&profile) == sender_addr);

            test_scenario::return_to_sender(scenario, profile);
        };

        test_scenario::next_tx(scenario, @0x1);
        {
            let profile = test_scenario::take_from_sender<Profile>(scenario);
            let mut database = test_scenario::take_shared<Database>(scenario);
            assert!(profile::get_database_profiles_len(&database) == 1, 1);

            // change sender
            let ctx = tx_context::dummy();
            assert!(profile::get_profile_owner(&profile) != ctx.sender());
            // should abort
            profile::delete_profile(&mut database, profile, &ctx);
            test_scenario::return_shared(database);
        };

        test_scenario::end(scenario_test);
    }
}