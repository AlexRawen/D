/*
* Name          : BookingClone
* Created By    : Fedor Golovanov (fgolovanov@newmarketinc.com)
* Created Date  : Jul 20th 2017
* Description   : Clones the booking with the inquiries and events
* Dependencies  : SObjectDataLoader.cls
* Operations    : Initialize booking clone page interface. Calls SObjectDataLoader class
*                 to serialize and deserialize (=clone) bookings with the related objects one by one.
*                 Generates the result table.
*/

public with sharing class BookingClone {
    
    //The number of new clone instancies to add to the list when the user clicks 'Add More'
    public Integer numOfClones{get;set{numOfClones = value;}}
    //List of the cloned instancies - populated on demand
    public List<BookingCloneInstance> clones{get; set;}
    //JSON with the object ids to skip(do not clone) during the clone
    public String omitClonesIdsJSON {get;set;}
    //JSON with the clone instansies used on the page
    public String clonesJSON{get; set;}
    //Concatenated errors occured during the clone to display on the page if required
    public String errors {get;set;}
    //As clone happed async in several iterations identifies if error occured in any iteration 
    public Boolean errorOccured {get;set;}
    //Varaible to start clone from the page
    public Boolean startCloning {get;set;}
    //Used to display the field on the apex page 
    public nihrm__Booking__c booking {get;set;}
    //Used to display the field on the apex page 
    public String clonesName {get;set;}
    //Initial booking Id as JSON used to serialize booking
    public String bookingIdAsJSON {get;set;}
    //Max number of clones that potentially can be added to the page
    public Integer NUM_CLONES_TO_ADD {get;set;}
    
    //Add more clones instancies on the page
    public void addMore()
    {
        // append numOfClones to the new booking clone list
        for (Integer idx = 0; idx < numOfClones; idx++)
        {
            clones.add(new BookingCloneInstance(new nihrm__Booking__c(Id = booking.Id, 
                                                                      nihrm__CutoffDate__c = booking.nihrm__CutoffDate__c)));
        }
    }

    //Starts the clone, fired from the page 'Clone' button
    public PageReference cloneBookings() 
    {
        //Validate clone instancies
        List<BookingCloneInstance> validInstancies = new List<BookingCloneInstance>();
        clonesJSON = null;

        for(BookingCloneInstance cloneInstance : clones){
            if(cloneInstance.booking.nihrm__CutoffDate__c != null && 
               cloneInstance.booking.nihrm__CutoffDate__c >= Date.today() && 
               cloneInstance.booking.nihrm__Location__c != null){
                validInstancies.add(cloneInstance);
            }
        }
        if(!validInstancies.isEmpty())
            clonesJSON = JSON.serialize(validInstancies);
        startCloning = true;
        return null;

    }

    //Resets clone script varaible
    public PageReference resetCloneBookings() 
    {
        startCloning = false;
        return null;
    }

    //'Cancel' button logic
    public PageReference cancel() 
    {
        return new PageReference('/' + String.ValueOf(booking.Id));
    }

    //Set page's initail values such as number of clone instancies, booking to clone
    public BookingClone() 
    {   
        try {
            Id bookingId = ApexPages.currentPage().getParameters().get('id');

            booking = [SELECT Id,
                                  Name,
                                  nihrm__CateringManager__c,
                                  nihrm__ServiceManager__c,
                                  nihrm__OtherManager__c,
                                  nihrm__ServiceAssistant__c,
                                  nihrm__OtherSource1__c,
                                  nihrm__OtherSource2__c,
                                  nihrm__OtherSource3__c,
                                  nihrm__OtherSource4__c,
                                  nihrm__Account__c,
                                  nihrm__Account__r.Name,
                                  nihrm__BookingContact__c,
                                  nihrm__BookingContact__r.Name, 
                                  nihrm__ArrivalDate__c,
                                  nihrm__CutoffDate__c,
                                  OwnerId,
                                  National_Sales_Owner__c,
                                  nihrm__Inquiry__c 
                           FROM nihrm__Booking__c 
                           WHERE Id =: bookingId];

            booking.nihrm__CutoffDate__c = booking.nihrm__ArrivalDate__c;

            Set<Id> skipClonning = new Set<Id>{ booking.nihrm__Account__c, 
                                                booking.nihrm__BookingContact__c, 
                                                booking.OwnerId,
                                                booking.nihrm__CateringManager__c,
                                                booking.nihrm__ServiceManager__c,
                                                booking.nihrm__OtherManager__c,
                                                booking.nihrm__ServiceAssistant__c,
                                                booking.nihrm__OtherSource1__c,
                                                booking.nihrm__OtherSource2__c,
                                                booking.nihrm__OtherSource3__c,
                                                booking.nihrm__OtherSource4__c, 
                                                booking.National_Sales_Owner__c,
                                                booking.nihrm__Inquiry__c 
                                              };

            skipClonning.remove(null);
            omitClonesIdsJSON = JSON.serialize(skipClonning);
            clonesName = (booking.nihrm__Account__c != null ? booking.nihrm__Account__r.Name : '') + 
                         (booking.nihrm__BookingContact__c != null ? ' - ' + booking.nihrm__BookingContact__r.Name : '');  
            bookingIdAsJSON = JSON.serialize(bookingId);
            clones = new List<BookingCloneInstance>();
            NUM_CLONES_TO_ADD = 20;
            numOfClones = 6;
            addMore();
        
        }catch (Exception ex) {
            System.debug('Exception Occured: ' + ex.getMessage());
        }
    }

    public class BookingCloneInstance{
        //mcode
        public boolean isInquiryShouldBeCloned{get; set;}
        public nihrm__Booking__c booking{get; set;}

        public BookingCloneInstance(nihrm__Booking__c booking){
            //mcode
            isInquiryShouldBeCloned = false;
            this.booking = booking;  
        }
    }

    //Copy initial values and related objects 
    @RemoteAction
    public static String serialize(String bookingIdsAsJSON) 
    {
        SObjectDataLoader.SerializeConfig config = new SObjectDataLoader.SerializeConfig();
        config = config
            .followChild(nihrm__BookingEvent__c.nihrm__Booking__c)
            .keepValue(nihrm__Booking__c.nihrm__Account__c)
            .keepValue(nihrm__Booking__c.RecordTypeId)
            .keepValue(nihrm__Booking__c.nihrm__BookingContact__c)
            .keepValue(nihrm__Booking__c.OwnerId)
            .keepValue(nihrm__Booking__c.nihrm__CateringManager__c)
            .keepValue(nihrm__Booking__c.nihrm__ServiceManager__c)
            .keepValue(nihrm__Booking__c.nihrm__OtherManager__c)
            .keepValue(nihrm__Booking__c.nihrm__ServiceAssistant__c)
            .keepValue(nihrm__Booking__c.nihrm__OtherSource1__c)
            .keepValue(nihrm__Booking__c.nihrm__OtherSource2__c)
            .keepValue(nihrm__Booking__c.nihrm__OtherSource3__c)
            .keepValue(nihrm__Booking__c.nihrm__OtherSource4__c)
            .keepValue(nihrm__Booking__c.National_Sales_Owner__c)
            .keepValue(nihrm__BookingEvent__c.OwnerId)
            .keepValue(nihrm__BookingEvent__c.RecordTypeId)
            .keepValue(nihrm__BookingEvent__c.nihrm__Account__c);
        return SObjectDataLoader.serialize((Set<Id>)JSON.deserialize(bookingIdsAsJSON, Set<Id>.class), config);
    }

    //Change the values on the copied objects and insert
    @RemoteAction
    public static SObjectDataLoader.DeserializeResponse deserialize(String recordsAsJSON, String originalArrival, 
                                                                    String newArrival, String newPropertyId, 
                                                                    String clonesName, String omitClonesIds, String isInquiryShouldBeCloned)
    {
        SObjectDataLoader.clonesName = clonesName;
        SObjectDataLoader.omitClonesIdsJSON = (Set<Id>)JSON.deserialize(omitClonesIds, Set<Id>.class);
        SObjectDataLoader.shiftDays = Date.ValueOf(originalArrival).daysBetween(Date.ValueOf(newArrival));
        SObjectDataLoader.clonedLocation = [SELECT Id, Name, nihrm__UnassignedFunctionRoom__c FROM nihrm__Location__c WHERE Id =: newPropertyId];
        SObjectDataLoader.isInquiryShouldBeCloned = (isInquiryShouldBeCloned == 'true');

        return SObjectDataLoader.deserialize(recordsAsJSON);
    }

    //Generete the table with the clone results
    @RemoteAction
    public static String createResultsTable(String idsAsJSON)
    {
        String resultTable = '';

        Set<String> ids = (Set<String>)JSON.deserialize(idsAsJSON, Set<String>.class);

        String cellLabel = '<div class="slds-p-horizontal_small slds-size_1-of-8">' +
                            '<div class="slds-form-element">' +
                                '<label class="slds-form-element__{!what}">{!content}</label>' +
                            '</div>' +
                          '</div>';

        resultTable += '<div class="slds-m-vertical--x-large"></div>';   
        resultTable += '<div class="slds-notify_container slds-is-relative" style="z-index: 5"> ' + 
                            '<div style="background-color:light-grey" class="slds-notify slds-notify--alert slds-theme--alert-texture" role="alert">' + 
                                '<span class="slds-assistive-text">Info</span>' + 
                                '<h1><b>Clone Results</b></h1>' + 
                            '</div>' + 
                        '</div>';
        resultTable += '<div class="slds-p-vertical_x-small"></div>';                 
        resultTable += '<div class="slds-grid slds-wrap">'; 

        resultTable += cellLabel.replace('{!content}', 'Booking Post As').replace('{!what}', 'label');
        resultTable += cellLabel.replace('{!content}', 'Event Date').replace('{!what}', 'label');
        resultTable += cellLabel.replace('{!content}', 'Departure').replace('{!what}', 'label');
        resultTable += cellLabel.replace('{!content}', 'Account').replace('{!what}', 'label');
        resultTable += cellLabel.replace('{!content}', 'Main Contact').replace('{!what}', 'label');
        resultTable += cellLabel.replace('{!content}', 'Property').replace('{!what}', 'label');
        resultTable += cellLabel.replace('{!content}', 'Inquiry').replace('{!what}', 'label');
        resultTable += cellLabel.replace('{!content}', 'Created Date').replace('{!what}', 'label');

        for(nihrm__Booking__c booking:[SELECT Id,
                                             Name, 
                                             nihrm__ArrivalDate__c,
                                             nihrm__DepartureDate__c,
                                             nihrm__Account__c,
                                             nihrm__Account__r.Name,
                                             nihrm__BookingContact__c,
                                             nihrm__BookingContact__r.Name,
                                             nihrm__Inquiry__c,
                                             nihrm__Inquiry__r.Name,
                                             nihrm__Location__r.Name,
                                             CreatedDate
                                     FROM nihrm__Booking__c 
                                     WHERE Id IN : ids]){

            resultTable += cellLabel.replace('{!content}', '<a target="_blank" href="/' + booking.Id + '">' + booking.Name + '</a>').replace('{!what}', 'control');
            resultTable += cellLabel.replace('{!content}', String.ValueOf(booking.nihrm__ArrivalDate__c)).replace('{!what}', 'control');
            resultTable += cellLabel.replace('{!content}', String.ValueOf(booking.nihrm__DepartureDate__c)).replace('{!what}', 'control');
            resultTable += cellLabel.replace('{!content}', booking.nihrm__Account__c != null ? '<a target="_blank" href="/' + booking.nihrm__Account__c + '">' + booking.nihrm__Account__r.Name + '</a>' : '').replace('{!what}', 'control');
            resultTable += cellLabel.replace('{!content}', booking.nihrm__BookingContact__c != null ? '<a target="_blank" href="/' + booking.nihrm__BookingContact__c + '">' + booking.nihrm__BookingContact__r.Name + '</a>' : '').replace('{!what}', 'control');
            resultTable += cellLabel.replace('{!content}', booking.nihrm__Location__r.Name).replace('{!what}', 'control');
            resultTable += cellLabel.replace('{!content}', booking.nihrm__Inquiry__c != null ? '<a target="_blank" href="/' + booking.nihrm__Inquiry__c + '">' + booking.nihrm__Inquiry__r.Name + '</a>' : '').replace('{!what}', 'control');
            resultTable += cellLabel.replace('{!content}', String.ValueOf(booking.CreatedDate)).replace('{!what}', 'control');
            resultTable += '<div class="slds-p-vertical_xx-small"></div>';

        }

        resultTable += '</div>';

        return resultTable;
    }

    //Set up cloned objects to calculate rollup values, we can hit the limits if we do it synchronously
    @RemoteAction
    public static String setRollupsActivated(String idsAsJSON)
    {
        //Get serialized ids
        Set<String> ids = (Set<String>)JSON.deserialize(idsAsJSON, Set<String>.class);
        ids.remove(null);

        //Activate rollups on events
        List<nihrm__BookingEvent__c> events = new List<nihrm__BookingEvent__c>([SELECT Id FROM nihrm__BookingEvent__c WHERE Id IN : ids]);
        try
        {
            for(nihrm__BookingEvent__c event : events)
            {
                event.nihrm__CalculateRevenue__c = true;
            }
            update events;

        }
        catch(Exception ex)
        {
            return 'The error occured on the setting rollups activated on booking events: ' + ex.getMessage();
        }

        //Activate rollups on bookings
        List<nihrm__Booking__c> bookings = new List<nihrm__Booking__c>([SELECT Id FROM nihrm__Booking__c WHERE Id IN : ids]);
        try
        {
            for(nihrm__Booking__c booking : bookings)
            {
                booking.nihrm__CalculateEventRevenue__c = true;
                booking.nihrm__CalculateGuestroomRevenue__c = true;
            }
            update bookings;

        }
        catch(Exception ex)
        {
            return 'The error occured on the setting rollups activated on bookings: ' + ex.getMessage();
        }
        
        return 'Successfully set rollups activated.';
    } 

    //Remove all cloned objects in case any error occured during clone iteration
    @RemoteAction
    public static String rollbackCloned(String idsAsJSON) 
    {
        Set<String> ids = (Set<String>)JSON.deserialize(idsAsJSON, Set<String>.class);
        try
        {
            delete [SELECT Id FROM nihrm__BookingEvent__c WHERE Id IN :ids];
            delete [SELECT Id FROM nihrm__Booking__c WHERE Id IN :ids];
            delete [SELECT Id FROM nihrm__Inquiry__c WHERE Id IN :ids];   
        }
        catch(Exception ex)
        {
            return 'The error occured on the rollback: ' + ex.getMessage();
        }

        return 'Successfully rolled back.';
    }    

}