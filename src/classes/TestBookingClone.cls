/*
* Name          : TestBookingClone
* Created By    : Fedor Golovanov (fgolovanov@newmarketinc.com)
* Created Date  : Jan 31th 2018
* Description   : Clones the booking with the inquiries and events
* Dependencies  : SObjectDataLoader.cls
* Operations    : Initialize booking clone page interface. Calls SObjectDataLoader class
*                 to serialize and deserialize (=clone) bookings with the related objects one by one.
*                 Generates the result table.
* Testing       : BookingClone.cls(80%)
*/

@isTest
private class TestBookingClone {

    private static Account acc;
    private static Contact cont;
    private static nihrm__Location__c prop;
    private static nihrm__Booking__c booking;
    private static nihrm__BookingEvent__c bookingEvent;
    private static nihrm__FunctionRoom__c funcRoom;

    private static Account createAccount(String name){
        acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    private static void createAccountProperty(Id accId, Id propId){
        nihrm__AccountProperty__c accProp = new nihrm__AccountProperty__c(nihrm__Account__c = accId,
                                                                          nihrm__Property__c = propId);
        insert accProp;
    }

    private static Contact createContact(String name, Id accId){
        cont = new Contact(LastName = name, AccountId = accId);
        insert cont;
        return cont;
    }

    private static nihrm__Location__c createProperty(String name){
        prop = new nihrm__Location__c(
            Name = name,
            nihrm__AddressLine1__c = 'AddressLine1',
            nihrm__City__c = 'Moscow',
            nihrm__CountryCode__c = 'RU', 
            nihrm__PostalCode__c = '012345',
            nihrm__SystemOfMeasurement__c = 'Standard',
            nihrm__TimeZone__c = 'GMT+03:00 Moscow Standard Time (Europe/Moscow)'
        );
        insert prop;
        return prop;
    }

    private static nihrm__Booking__c createBooking(String name, Id accountId, Id locationId, Date dt){
        booking = new nihrm__Booking__c(
            Name = name,
            nihrm__ArrivalDate__c = dt,
            nihrm__DepartureDate__c = dt.addDays(1),
            nihrm__Location__c = locationId,
            nihrm__Account__c = accountId,
            nihrm__BookingMarketSegmentName__c = 'Corporate',
            nihrm__LeadSourceName__c = 'Advertising / Promotion',
            nihrm__BookingStatus__c = 'Tentative'
        );
        insert booking;
        return booking;
    }

    private static nihrm__BookingEvent__c createBookingEvent(String name, Id bookingId, Id locationId, Id funcroomId, Date dt){
        bookingEvent = new nihrm__BookingEvent__c(
            Name = name,
            nihrm__Booking__c = bookingId,
            nihrm__Location__c = locationId,
            nihrm__FunctionRoom__c = funcroomId,
            nihrm__BookedDate__c = dt,
            nihrm__StartDate__c = dt,
            nihrm__EndDate__c = dt
        );
        insert bookingEvent;
        return bookingEvent;
    }

    private static nihrm__FunctionRoom__c createFunctionRoom(nihrm__Location__c loc){
        funcRoom = new nihrm__FunctionRoom__c(
                Name = 'Test-' + loc.Name + '-' + 1,
                nihrm__Location__c = loc.Id,
                nihrm__SortOrder__c = 1
        );
        insert funcRoom;
        return funcRoom;
    }

    //Create test data from the helper methods: Account, Booking, Location, Booking Event as we can start the clone process
    public static void createTestData(){
        acc = createAccount('Test Account');
        prop = createProperty('Test Property');
        createAccountProperty(acc.Id, prop.Id);
        booking = createBooking('Merge Unit Test', acc.Id, prop.Id, Date.today() + 1);
        funcRoom = createFunctionRoom(prop);
        bookingEvent = createBookingEvent('Test Event', booking.Id, prop.Id, funcRoom.Id, Date.today() + 1);
    }

    //Verify that on data insert we have 1 Account, Location, Booking, Booking Event, Function Room  
    @isTest static void testDataInsertion()
    {
        Test.startTest();
            createTestData();
        Test.stopTest();
        System.assertEquals([SELECT COUNT() FROM nihrm__Location__c], 1);
        System.assertEquals([SELECT COUNT() FROM Account], 1);
        System.assertEquals([SELECT COUNT() FROM nihrm__Booking__c], 1);
        System.assertEquals([SELECT COUNT() FROM nihrm__BookingEvent__c], 1);
        System.assertEquals([SELECT COUNT() FROM nihrm__FunctionRoom__c], 1);
    }
    
     //Verify promotion clone varaibles initials
    @isTest static void testInitials()
    {
        Test.startTest();
            createTestData();
        Test.stopTest();
        //Set current page as Booking Clone page and put id parameter.
        Test.setCurrentPageReference(new PageReference('Page.BookingClone')); 
        System.currentPageReference().getParameters().put('id', booking.Id);
        
        //Verify initials
        BookingClone bc = new BookingClone();
        System.assertEquals(bc.numOfClones, 6);
        System.assertEquals(bc.startCloning, null);
        System.assertEquals(bc.clones.size(), bc.numOfClones);
        System.assertEquals(bc.clonesJSON, null);
        System.assertEquals(bc.errors, null);
        System.assertEquals(bc.errorOccured, null);
        System.assertEquals(bc.NUM_CLONES_TO_ADD, 20);
        System.assertEquals(bc.booking.Id, booking.Id);
        System.assertNotEquals(bc.clonesName, null);
        System.assertNotEquals(bc.bookingIdAsJSON, null);

    }
    
    //Verify that clone start end functions change startCloning varaible
    @isTest static void testCloneStartEnd()
    {
        Test.startTest();
            createTestData();
        Test.stopTest();
        //Set current page as Vooking Clone page and put id parameter.
        Test.setCurrentPageReference(new PageReference('Page.BookingClone')); 
        System.currentPageReference().getParameters().put('id', booking.Id);

        BookingClone bc = new BookingClone();
        //Set up arrival date (as we will do it from the page)
        for(BookingClone.BookingCloneInstance clone : bc.clones){
            clone.booking.nihrm__CutoffDate__c = Date.today() + 1;
            clone.booking.nihrm__Location__c = prop.Id;
        }
        System.assertEquals(bc.startCloning, null);
        bc.cloneBookings();
        System.assertEquals(bc.startCloning, true);
        bc.resetCloneBookings();
        System.assertEquals(bc.startCloning, false);
    }

    //Verify that cloning is working and we clone promotins and related objects. 
    @isTest static void testClone()
    {
        Test.startTest();
            createTestData();
        Test.stopTest();
        //Set current page as Vooking Clone page and put id parameter.
        Test.setCurrentPageReference(new PageReference('Page.BookingClone')); 
        System.currentPageReference().getParameters().put('id', booking.Id);

        BookingClone bc = new BookingClone();
        //Set up arrival date (as we will do it from the page)
        bc.clones[0].booking.nihrm__CutoffDate__c = Date.today() + 1;
        bc.clones[0].booking.nihrm__arrivaldate__c = Date.today() + 1;
        bc.clones[0].booking.nihrm__Location__c = prop.Id;

        String originalArrival = String.ValueOf(bc.clones[0].booking.nihrm__CutoffDate__c.year()) + '-' +
                                 String.ValueOf(bc.clones[0].booking.nihrm__CutoffDate__c.month()) + '-' +
                                 String.ValueOf(bc.clones[0].booking.nihrm__CutoffDate__c.day()); 

        String serializedData = BookingClone.serialize(JSON.serialize(new Set<Id>{booking.Id}));
        SObjectDataLoader.DeserializeResponse deserializedData = BookingClone.deserialize(serializedData,
                                                                                            originalArrival,
                                                                                            originalArrival, 
                                                                                            prop.Id, 
                                                                                            bc.clonesName, 
                                                                                            bc.omitClonesIdsJSON,
                                                                                            'true'
                                                                                            );
        System.assertEquals(deserializedData.exceptions, null);

        System.assertEquals([SELECT COUNT() FROM nihrm__Booking__c], 2);
        System.assertEquals([SELECT COUNT() FROM nihrm__BookingEvent__c], 2);
        System.assertEquals([SELECT COUNT() FROM nihrm__Inquiry__c], 1);

        BookingClone.createResultsTable(JSON.serialize(deserializedData.records));
    }

    //Verify that rollback is working and we revert all our chnages in case of error. 
    @isTest static void testRollBack()
    {   
        Test.startTest();
            createTestData();
        Test.stopTest();
        
        String result = BookingClone.rollbackCloned(JSON.serialize(new Set<String>{booking.Id, bookingEvent.Id}));

        System.assertEquals(result, 'Successfully rolled back.');
        System.assertEquals([SELECT COUNT() FROM nihrm__Booking__c], 0);
        System.assertEquals([SELECT COUNT() FROM nihrm__BookingEvent__c], 0); 
    }

    //Verify that set rollup activated function enables rollups for bookings and related events. 
    @isTest static void testSetRollupsActivated()
    {   
        Test.startTest();
            createTestData();
        Test.stopTest();
        
        BookingClone.setRollupsActivated(JSON.serialize(new Set<String>{booking.Id, bookingEvent.Id}));

        System.assertEquals([SELECT nihrm__CalculateRevenue__c 
                            FROM nihrm__BookingEvent__c 
                            WHERE Id =: bookingEvent.Id].nihrm__CalculateRevenue__c, true);
    }                         
    
}