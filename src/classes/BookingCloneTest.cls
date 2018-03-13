/***************************************************************************
Name          : BookingCloneTest
Created By    : Fedor Golovanov (fgolovanov@newmarketinc.com)
Created Date  : Jul 20th 2017
Dependencies  : BookingClone.cls, SObjectDataLoader.trigger
Operations    : Tests the booking clone functionality
Testing       : BookingClone.cls (85% Coverage), SObjectDataLoader (71% Coverage)
***************************************************************************/
@isTest
private class BookingCloneTest {

    private static nihrm__Booking__c booking;
    private static nihrm__Location__c property;
    private static nihrm__FunctionRoom__c funcroom;
    private static nihrm__FunctionRoom__c funcroomUnassigned;
    private static nihrm__GuestroomType__c guestroomtype;
    private static nihrm__GuestroomType__c rohguestroomtype;

    private static void createTestData()
    {
        //Account
        Account a = new account(name = 'Newmarket Inc.');
        a.nihrm__MarketSegmentName__c = 'Social';
        insert a;
        
        //Property
        property = new nihrm__Location__c(Name = 'TopGolf Company Property', nihrm__LocationCode__c = 'TGP');
        insert property;

        //Function rooms
        List<nihrm__FunctionRoom__c> rooms = new List<nihrm__FunctionRoom__c>();
        funcroom = new nihrm__FunctionRoom__c(Name = 'Luxapps',
                                               nihrm__IsActive__c = true, 
                                               nihrm__Location__c = property.Id, 
                                               nihrm__Property__c = 'TopGolf Company Property', 
                                               nihrm__DefaultMaxCapacity__c = 20);
        rooms.add(funcroom);
        funcroomUnassigned = new nihrm__FunctionRoom__c(Name = 'Unassigned', 
                                               nihrm__IsActive__c = true, 
                                               nihrm__Location__c = property.Id, 
                                               nihrm__Property__c = 'TopGolf Company Property', 
                                               nihrm__AllowMultiGroupBlocking__c = true);
        rooms.add(funcroomUnassigned);
        insert rooms;

        //Event classification
        nihrm__EventClassification__c eventclassification = new nihrm__EventClassification__c
        (
            Name = 'Breakfast', 
            nihrm__IsActive__c = true, 
            nihrm__DefaultAverageCheck1__c = 32,
            nihrm__DefaultAverageCheckFactor1__c = 'Per Person',
            nihrm__DefaultAverageCheck6__c = 32,
            nihrm__DefaultAverageCheckFactor6__c = 'Per Person'
        );
        insert eventclassification;

        //Room Types
        List<nihrm__GuestroomType__c> roomtypes = new list<nihrm__GuestroomType__c>();
        
        guestroomtype = new nihrm__GuestroomType__c(Name = 'Single Room',
                                                     nihrm__IsActive__c = true,
                                                     nihrm__Location__c = property.Id,
                                                     nihrm__Property__c = 'TopGolf Company Property',
                                                     nihrm__SortOrder__c = 1);
        roomtypes.add(guestroomtype);
        rohguestroomtype = new nihrm__GuestroomType__c(Name = 'ROH',
                                                     nihrm__IsActive__c = true,
                                                     nihrm__Location__c = property.Id,
                                                     nihrm__Property__c = 'TopGolf Company Property',
                                                     nihrm__SortOrder__c = 2, 
                                                     nihrm__IsRunOfHouse__c = true);
        roomtypes.add(rohguestroomtype);
        insert roomtypes;

        //Update property with required info
        property.nihrm__DefaultEventClassification__c = eventclassification.Id;
        property.nihrm__RohGuestroomType__c = rohguestroomtype.Id;
        property.nihrm__UnassignedFunctionRoom__c = funcroomUnassigned.Id;
        update property;

        //Booking
        booking = new nihrm__Booking__c
        (
            Name = 'Pool Party',
            nihrm__BookingMarketSegmentName__c = 'SOCIAL',
            nihrm__Account__c = a.Id,
            nihrm__ArrivalDate__c = date.newinstance(2020,1,3),
            nihrm__DepartureDate__c = date.newinstance(2020,1,7),
            nihrm__Location__c = property.Id,
            nihrm__BookingStatus__c = 'Prospect'
        );
        insert booking;

        //Booking Events
        List<nihrm__BookingEvent__c> events = new List<nihrm__BookingEvent__c>();
        for(Integer e = 0; e < 2; e++)
        {
            nihrm__BookingEvent__c event = new nihrm__BookingEvent__c
            (
                Name = 'Event ' + String.ValueOf(e),
                nihrm__Booking__c = booking.Id,
                nihrm__Location__c = property.Id,
                nihrm__FunctionRoom__c = rooms[0].Id,
                nihrm__BookedDate__c = date.newinstance(2020,1,2),
                nihrm__StartDate__c = date.newinstance(2020,1,3),
                nihrm__EndDate__c = date.newinstance(2020,1,4)
            );

            events.add(event);
        }

        insert events;
    }

    //Verify that on data insert we have 1 nihrm booking, 2 events, 0 inquiries
    @isTest static void testDataCreation() {
        createTestData();
        System.assertEquals([SELECT COUNT() FROM nihrm__Booking__c], 1);
        System.assertEquals([SELECT COUNT() FROM nihrm__BookingEvent__c], 2);
        System.assertEquals([SELECT COUNT() FROM nihrm__Inquiry__c], 0);
    }

    //Verify booking clone varaibles initials
    @isTest static void testInitials()
    {
        createTestData();
        //Set current page as Booking Clone page and put id parameter.
        Test.setCurrentPageReference(new PageReference('Page.BookingClone')); 
        System.currentPageReference().getParameters().put('id', booking.Id);
        
        //Verify initials
        BookingClone bc = new BookingClone();
        System.assertEquals(bc.booking.Name, 'Pool Party');
        System.assertEquals(bc.bookingIdAsJSON, JSON.serialize(booking.Id));
        System.assertEquals(bc.clones.size(), 6);

    }

    //Verify that clone start end functions change startCloning varaible. Also 
    @isTest static void testCloneStartEnd()
    {
        createTestData();
        //Set current page as Booking Clone page and put id parameter.
        Test.setCurrentPageReference(new PageReference('Page.BookingClone')); 
        System.currentPageReference().getParameters().put('id', booking.Id);

        BookingClone bc = new BookingClone();
        for(BookingClone.BookingCloneInstance cloneInstance : bc.clones){
            cloneInstance.booking.nihrm__CutoffDate__c = Date.today() + 2; 
            cloneInstance.booking.nihrm__Location__c = property.Id;
        }

        bc.resetCloneBookings();
        System.assertEquals(bc.startCloning, false);
        
        bc.cloneBookings();
        System.assertEquals(bc.startCloning, true);
        System.assertNotEquals(bc.clonesJSON, null);
    }

    //Verify that cloning is working and we bookings promotins and related objects. 
    @isTest static void testClone()
    {
        Test.startTest();
            createTestData();
        Test.stopTest();
        //Set current page as Promotion Clone page and put ids parameter.
        Test.setCurrentPageReference(new PageReference('Page.BookingClone')); 
        System.currentPageReference().getParameters().put('id', booking.Id);

        BookingClone bc = new BookingClone();
        String serializedData = BookingClone.serialize(JSON.serialize(new Set<Id>{bc.booking.Id}));
        SObjectDataLoader.deserializeResponse response = BookingClone.deserialize(serializedData, '2020-01-02', '2020-03-01', String.ValueOf(property.Id), bc.clonesName, bc.omitClonesIdsJSON, 'true');
        
        //Check that result table was generated
        System.assertNotEquals(BookingClone.createResultsTable(JSON.serialize(response.records)), '');

    }

    //Verify that rollback is working and we revert all our changes in case of error. 
    @isTest static void testRollBack()
    {
        Test.startTest();
            createTestData();
        Test.stopTest();
        //Set current page as Promotion Clone page and put ids parameter.
        Test.setCurrentPageReference(new PageReference('Page.BookingClone')); 
        System.currentPageReference().getParameters().put('id', booking.Id);

        BookingClone bc = new BookingClone();
        String serializedData = BookingClone.serialize(JSON.serialize(new Set<Id>{bc.booking.Id}));
        SObjectDataLoader.deserializeResponse response = BookingClone.deserialize(serializedData, '2020-01-02', '2020-03-01', String.ValueOf(property.Id), bc.clonesName, bc.omitClonesIdsJSON, 'true');

        String result = BookingClone.rollbackCloned(JSON.serialize(response.records));

        System.assertEquals(result, 'Successfully rolled back.');
        System.assertEquals([SELECT COUNT() FROM nihrm__Booking__c], 1);
        System.assertEquals([SELECT COUNT() FROM nihrm__BookingEvent__c], 2);
        System.assertEquals([SELECT COUNT() FROM nihrm__Inquiry__c], 0);
    }

    @isTest static void testSObjectDataLoader()
    {
        Test.startTest();
            createTestData();
        Test.stopTest();
        //Set current page as Promotion Clone page and put ids parameter.
        SObjectDataLoader.SerializeConfig config = new SObjectDataLoader.SerializeConfig();
        config = config.auto(Schema.getGlobalDescribe().get('nihrm__Booking__c'));
    }

}