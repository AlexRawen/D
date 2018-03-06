/**
 * Copyright (c) 2012, Andrew Fawcett
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the Andrew Fawcett, inc nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

/**
 * Serializes and Deserializes SObject records and related child and referenced records using the Apex JSON support
 *
 *   See https://github.com/afawcett/apex-sobjectdataloader for known issues, restrictions and TODO's
 *
 **/
public with sharing class SObjectDataLoader 
{
    /**
     * Configuration uses a Fluent method design (http://en.wikipedia.org/wiki/Fluent_interface), 
     **/
    public class SerializeConfig
    {
        protected Set<Schema.SObjectField> followRelationships;
        protected Set<Schema.SObjectField> keepRelationshipValues;
        protected Set<Schema.SObjectField> followChildRelationships;
        protected Set<Schema.SObjectField> omitFields;
        protected Map<String,List<String>> userFieldBlackListMap;
        protected Map<String,List<String>> userChildRelationshipBlackListMap;
        protected Set<String> blacklistedNamespacePrefix;
        protected Boolean omitCurrencyField;
        protected Map<Schema.SObjectType, Map<String, Schema.SObjectField>> objectFieldDescribeMap;
        protected Integer maxLookupDepth;
        protected Integer maxChildDepth;
        
        
        public SerializeConfig()
        {   
            followRelationships = new Set<Schema.SObjectField>();
            keepRelationshipValues = new Set<Schema.SObjectField>(); 
            followChildRelationships = new Set<Schema.SObjectField>();
            omitFields = new Set<Schema.SObjectField>();    
            userFieldBlackListMap = new Map<String,List<String>>(); 
            userChildRelationshipBlackListMap = new Map<String,List<String>>();     
            blacklistedNamespacePrefix = new Set<String>();
            omitCurrencyField =false;
            objectFieldDescribeMap = new Map<Schema.SObjectType, Map<String, Schema.SObjectField>>();
            maxLookupDepth = 3;
            maxChildDepth = 3;
        }
        
        /**
         * Provide a field that represents the lookup relationship the serializer should follow
         **/
        public SerializeConfig follow(Schema.SObjectField relationshipField)
        {
            followRelationships.add(relationshipField);
            return this;
        }
        
        /**
         * Keep relationship Id value without following (=serializing) the related object
         **/
        public SerializeConfig keepValue(Schema.SObjectField relationshipField)
        {
            keepRelationshipValues.add(relationshipField);
            return this;
        }
        
        /**
         * Provide a field that represents a parent child relationship the serializer should follow
         **/
        public SerializeConfig followChild(Schema.SObjectField relationshipField)
        {
            followChildRelationships.add(relationshipField);
            return this;
        }
        
        /**
         * Define maximum depth to where relationship fields are followed
         **/
        public SerializeConfig maxLookupDepth(Integer value)
        {
            maxLookupDepth = value;
            return this;
        }
        
        /**
         * Define maximum depth to where child records are followed
         **/
        public SerializeConfig maxChildDepth(Integer value)
        {
            maxChildDepth = value;
            return this;
        }
        
        /**
         * Provide a field that the serializer should omit from the serialized output
         **/
        public SerializeConfig omit(Schema.SObjectField omitField)
        {
            omitFields.add(omitField);
            if(followRelationships.contains(omitField))
                followRelationships.remove(omitField);
            if(keepRelationshipValues.contains(omitField))
                keepRelationshipValues.remove(omitField);
            if(followChildRelationships.contains(omitField))
                followChildRelationships.remove(omitField);
            return this;
        }
        
        /** 
         * Automatically configure (removes all previous configuration)
         *  Skip known system lookup and child relationships but include the rest (direct children only) upto certain depth, 
         *  Caller can always add or omit specific via follow or omit methods
         **/
        public SerializeConfig auto(Schema.SObjectType sObjectType)
        {
            followRelationships = new Set<Schema.SObjectField>();
            keepRelationshipValues = new Set<Schema.SObjectField>(); 
            followChildRelationships = new Set<Schema.SObjectField>();
            omitFields = new Set<Schema.SObjectField>();
            Set<Schema.SObjectType> searched = new Set<Schema.SObjectType>();
            Set<Schema.SObjectType> searchedParentOnly = new Set<Schema.SObjectType>(); // This is a set of objecttypes where only parent links have been searched
            searchRelationships(sObjectType, 0, 0, true, searched, searchedParentOnly); 
            return this;    
        }
        
        /**
         * Provide a map that represents the object field relationship the serializer should whitelist
         **/
        public SerializeConfig addToUserChildRelationShipBlackList(Map<String,List<String>> childRelationShipBlackListMap)
        {
            UserChildRelationshipBlackListMap.putAll(childRelationShipBlackListMap);
            return this;
        }
        
        /**
         * Provide a map that represents the object child relationship the serializer should whitelist
         **/
        public SerializeConfig addToUserFieldBlackList(Map<String,List<String>> fieldBlackListMap)
        {
            userFieldBlackListMap.putAll(fieldBlackListMap);
            return this;
        }
        
        public SerializeConfig addToBlacklistedNamespace(Set<String> NamespaceList)
        {
            blacklistedNamespacePrefix.addAll(NamespaceList);
            return this;
        }
        
        /**
         * Method adds blacklist Fields common for all Objects to fieldBlacklist 
        **/
        public SerializeConfig omitCommonFields(Set<String> fieldnames)
        {
            if(fieldnames!=null && fieldnames.size()>0)
            {
                fieldBlacklist.addAll(fieldnames);
                if(fieldnames.contains('CurrencyIsoCode'))
                    omitCurrencyField = true;
            }
            return this;
        }
        
        /**
         * Seek out recursively relationships
         **/
        private void searchRelationships(Schema.SObjectType sObjectType, Integer lookupDepth, Integer childDepth, Boolean searchChildren, Set<Schema.SObjectType> searched, Set<Schema.SObjectType> searchedParentOnly)
        {       
            // Stop infinite recursion and checks that an object shuold not be searched twice, unless the scope of the search is different  
            if(searched.contains(sObjectType) || (searchChildren == false && searchedParentOnly.contains(sObjectType)) || lookupDepth > 2 || childDepth > 3) // TODO: Make max depth configurable
                return;

            // Store this object type so that it is not searched again
            if (searchChildren) {
                searched.add(sObjectType);
            } else {
                searchedParentOnly.add(sObjectType);
            }
            Schema.DescribeSObjectResult sObjectDescribe = sObjectType.getDescribe();
            String sObjectName = sObjectType.getDescribe().getName();
            // Following children? (only set for descendents of the top level object)
            if(searchChildren)
            {
                List<Schema.ChildRelationship> childRelationships = sObjectDescribe.getChildRelationships();
                Set<String> userChildRelationshipBlackListSet = new Set<String>();      
                if(userChildRelationshipBlackListMap.get(sObjectName)!= null && userChildRelationshipBlackListMap.get(sObjectName).size()>0)
                {
                    userChildRelationshipBlackListSet.addAll(userChildRelationshipBlackListMap.get(sObjectName));
                }
                for(Schema.ChildRelationship childRelationship : childRelationships)
                {
                    // Determine which child relationships to automatically follow
                    String childRelationshipName = childRelationship.getRelationshipName();
                    if(childRelationshipName==null || 
                       childRelationshipBlacklist.contains(childRelationshipName) || userChildRelationshipBlackListSet.contains(childRelationshipName) || matchNameSpaceForObject(childRelationshipName)) // Skip relationships without names and those whitelisted
                        continue;
                    if(childRelationshipName.endsWith('Histories')) // Skip relationships ending in Histories (TODO: consider a RegEx approach?)
                        continue;
                    if(!childRelationship.isCascadeDelete()) // Skip relationships for none owned records (aka only follow master-detail relationships)
                        continue;
                    followChild(childRelationship.getField()).
                        searchRelationships(childRelationship.getChildSObject(), lookupDepth, childDepth+1, true, searched, searchedParentOnly);
                }
            }
            Map<String, Schema.SObjectField> sObjectFields = objectFieldDescribeMap.get(sObjectType);
            if (sObjectFields == null)
            {
                sObjectFields = sObjectDescribe.fields.getMap();
                objectFieldDescribeMap.put(sObjectType, sObjectFields);
            }
            
            Set<String> userBlackListSet = new Set<String>();
            if(userFieldBlackListMap.get(sObjectName)!= null && userFieldBlackListMap.get(sObjectName).size()>0)
            {
                userBlackListSet.addAll(userFieldBlackListMap.get(sObjectName));
            }           
            // Follow lookup relationships to long as they have not previously been added as child references and are not whitelisted
            //If the Sobject Field is referenceTo as 'User' and 'Organization' then restrict it to search its Relationships 

            for(Schema.SObjectField sObjectField : sObjectFields.values())
                if(sObjectField.getDescribe().getType() == Schema.DisplayType.Reference)
                {
                    Boolean omitRefernceToFields = false;
                    for(Schema.sObjectType refernceToType : sObjectField.getDescribe().getReferenceTo()){
                        if(referenceToBlacklist.contains(refernceToType.getDescribe().getName()))
                            omitRefernceToFields = true;
                    }
                    if(!followChildRelationships.contains(sObjectField) && !relationshipBlacklist.contains(sObjectField.getDescribe().getName()) && !omitRefernceToFields && !userBlackListSet.contains(sObjectField.getDescribe().getName()) && !matchNameSpaceForObject(sObjectField.getDescribe().getName()))
                    {
                        if(sObjectField.getDescribe().getReferenceTo()!=null && sObjectField.getDescribe().getReferenceTo().size()>0)
                            follow(sObjectField).
                                searchRelationships(sObjectField.getDescribe().getReferenceTo()[0], lookupDepth+1, childDepth, false, searched, searchedParentOnly);
                    }
                }
                else if(userBlackListSet.contains(sObjectField.getDescribe().getName()) || matchNameSpaceForObject(sObjectField.getDescribe().getName()))
                {
                    omit(sObjectField);
                }
                else if(fieldBlacklist.contains(sObjectField.getDescribe().getName()))
                {
                    omit(sObjectField);
                } 
        }

        private Boolean matchNameSpaceForObject(String ObjectName)
        {
            Boolean namespaceMatched = false;
            for(String namespaceExcluded : blacklistedNamespacePrefix)
            {
                namespaceExcluded = namespaceExcluded.trim()+'__';
                if(ObjectName.startsWith(namespaceExcluded))
                    namespaceMatched = true;
            }
            return namespaceMatched;
        } 
        // Standard fields that are not included when using the auto config
        private Set<String> relationshipBlacklist = 
            new Set<String>
                { 'OwnerId',
                  'CreatedById',
                  'LastModifiedById',
                  'ProfileId'
                };
                
        // Standard child relationships that are not included when using the auto config
        private Set<String> childRelationshipBlacklist = 
            new Set<String> 
                { 'Shares', 
                  'ProcessInstances', 
                  'ProcessSteps', 
                  'Tasks', 
                  'ActivityHistories', 
                  'Attachments', 
                  'FeedSubscriptionsForEntity', 
                  'Events', 
                  'Notes', 
                  'NotesAndAttachments', 
                  'OpenActivities', 
                  'Histories', 
                  'Feeds',
                  'CombinedAttachments',
                  'ContentDocuments',
                  'ContentVersions',
                  'AttachedContentDocuments',
                  'RecordAssociatedGroups'
                  };        
    
        // Standard RefernceTo that are not included when using the auto config 
        private Set<String> referenceToBlacklist = 
            new Set<String>
                { 'User',
                  'Organization'
                };
    
        // Standard fiels to be omitted
        private Set<String> fieldBlacklist = 
            new Set<String>
                {
                    'LastViewedDate',
                    'LastReferencedDate',
                    //below fields are compound fields
                    'MailingAddress',
                    'OtherAddress',
                    'BillingAddress',
                    'ShippingAddress',
                    'Address'
                };
                
    }

    public static Map<String, Map<String, Object>> fieldsDefaultByObject = new Map<String, Map<String, Object>>{
        'nihrm__booking__c' => new Map<String, Object>{
            'recordtypeid' => Schema.SObjectType.nihrm__Booking__c.getRecordTypeInfosByName().get('US - National Events Record Type').getRecordTypeId(),
            'nihrm__bookingstatus__c' => 'Prospect',
            'nihrm__bookeddate__c' => date.today()
        },
        'nihrm__bookingevent__c' => new Map<String, Object>{
            'recordtypeid' => Schema.SObjectType.nihrm__BookingEvent__c.getRecordTypeInfosByName().get('Standard Record Type').getRecordTypeId(),
            'nihrm__eventstatus__c' => 'Prospect',
            'nihrm__ismoveable__c' => true, 
            'nihrm__isposted__c' => true
        },
        'nihrm__inquiry__c' => new Map<String, Object>{
        }
    };
    
    public static Map<String, Set<String>> fieldsCopyByObject = new Map<String, Set<String>> {
        'nihrm__booking__c' => new Set<String>{
            'nihrm__istaxexempt__c', 
            'tax_exempt_fandbonly__c',
            'deposit_amount__c',
            'nihrm__leadsourcename__c',
            'nihrm__bookingmarketsegmentname__c',
            'name',
            'ownerid',
            'event_name_for_golf_bay_signs__c',
            'bay_sign_start_time__c',
            'booking_start_time__c',
            'booking_end_time__c',
            'catering_time__c',
            'multiple_menu_service_times__c',
            'catering_location__c',
            'guest_count__c',
            'topgolf_play__c',
            'topgolf_guest_count__c',
            'number_of_bays__c',
            'tg_start_time__c',
            'tg_end_time__c',
            'venue_buyouts__c',
            'beverage_package__c',
            'drink_package_service_time__c',
            'n_a_beverage_service_time__c',
            'nihrm__bookingtypename__c',
            'nihrm__groupresumefield1__c',
            'nihrm__groupresumefield7__c',
            'play_card_type__c',
            'bay_level__c',
            'bay_level_notes__c',
            'tg_gear_trophies__c',
            'transportation__c',
            'is_bartender_needed__c',
            'number_of_bartenders__c',
            'of_door_attendants__c',
            'of_golf_pros__c',
            'golf_pro_time__c',
            'of_tas__c',
            'ta_time__c',
            'event_revenue_minimum__c',
            'a_v_needed__c',
            'nihrm__comments__c',
            'internal_allergy_notes__c',
            'nihrm__account__c',
            'nihrm__bookingcontact__c',
            'national_sales_owner__c',
            'nihrm__arrivaldate__c',
            'nihrm__departuredate__c',
            'nihrm__bookeddate__c',
            'nihrm__cutoffdate__c',
            'nihrm__decisiondate__c',
            'nihrm__location__c',
            'nihrm__property__c',
            'nihrm__meetingclassname__c'
        },
        'nihrm__bookingevent__c' => new Set<String>{
            'name',
            'ownerid',
            'nihrm__booking__c',
            'nihrm__startdate__c',
            'nihrm__enddate__c',
            'nihrm__account__c',
            'nihrm__starttime12hour__c',
            'nihrm__starttime24hour__c',
            'nihrm__endtime12hour__c',
            'nihrm__endtime24hour__c',
            'nihrm__eventclassificationname__c',
            'nihrm__functionroomsetupname__c',
            'nihrm__setupduration__c',
            'nihrm__teardownduration__c',
            'nihrm__agreedattendance__c',
            'nihrm__forecastattendance__c'
        },'nihrm__inquiry__c' => new Set<String>{ 
            'name',
            'ownerid',
            'nihrm__arrivaldate__c',
            'recordtypeid'
        }   
    };

    public static Integer shiftDays;
    public static String clonesName;
    public static nihrm__Location__c clonedLocation;
    public static Set<Id> omitClonesIdsJSON;

    public static sObject flushFields(sObject sObj){
        
        String objName = sObj.getSObjectType().getDescribe().getName().toLowerCase();
        
        if(fieldsCopyByObject.containsKey(objName)){

            SObjectType objType = Schema.getGlobalDescribe().get(objName);
            Map<String, Schema.SObjectField> describeMap = objType.getDescribe().fields.getMap();

            for(String fieldName : describeMap.keySet()) {
                if(describeMap.get(fieldName).getDescribe().isUpdateable()) {
                    
                    //Null unnessary fields
                    if(!fieldsCopyByObject.get(objName).contains(fieldName)){
                        if(describeMap.get(fieldName).getDescribe().getType() == Schema.DisplayType.Boolean){
                            sObj.put(fieldName , false);
                        }else{
                            sObj.put(fieldName , null);
                        }
                    }else{
                        if(describeMap.get(fieldName).getDescribe().getType() == Schema.DisplayType.Date || describeMap.get(fieldName).getDescribe().getType() == Schema.DisplayType.DateTime){
                            if(sObj.get(fieldName) != null){
                                sObj.put(fieldName, Date.ValueOf(sObj.get(fieldName)) + shiftDays);
                            }
                        }
                    }

                    //Set up defaults
                    if(fieldsDefaultByObject.get(objName) != null && fieldsDefaultByObject.get(objName).keySet().contains(fieldName)){
                        sObj.put(fieldName , fieldsDefaultByObject.get(objName).get(fieldName));
                    }
                }
            }

            //Update property information
            sObj.put('nihrm__property__c', clonedLocation.Name);

            //Update name
            Datetime dt = Datetime.newInstance(Date.ValueOf( objName == 'nihrm__bookingevent__c' ? sObj.get('nihrm__startdate__c') : sObj.get('nihrm__arrivaldate__c')), Time.newInstance(0, 0, 0, 0));
            sObj.put('name', checkFieldLength(clonesName + ' - ' + dt.format('MM.dd.YY'), 80));

            //Update function room on events
            if(objName == 'nihrm__bookingevent__c'){
                sObj.put('nihrm__functionroom__c', clonedLocation.nihrm__UnassignedFunctionRoom__c);
            }

            if(objName == 'nihrm__booking__c'){
                sObj.put('nihrm__inquiry__c', createPrimaryInquiry((nihrm__Booking__c)sObj));
            }
        }

        return sObj;
    }

    public static Id createPrimaryInquiry(nihrm__Booking__c booking){
        
        //Have to skip the trigger on the tasks and events 
        //to not hit manage package "KORE ProSports" and unamanaged logic exception.

        ahsvc_Helper.enforceCodeSkip = true; 

        nihrm__Inquiry__c inq = new nihrm__Inquiry__c
        (
            name = booking.name,
            nihrm__contact__c = booking.nihrm__bookingcontact__c,
            nihrm__account__c = booking.nihrm__account__c,
            nihrm__leadsourcename__c = booking.nihrm__leadsourcename__c,
            nihrm__bookingtypename__c = booking.nihrm__bookingtypename__c,
            ownerid = booking.ownerid,
            recordtypeid = Schema.SObjectType.nihrm__Inquiry__c.getRecordTypeInfosByName().get('National Events Inquiry – Child').getRecordTypeId(),
            nihrm__arrivaldate__c = booking.nihrm__arrivaldate__c,
            nihrm__property__c = booking.nihrm__property__c,
            market_segment__c = booking.nihrm__bookingmarketsegmentname__c,
            nihrm__type__c = booking.nihrm__meetingclassname__c,
            nihrm__guests__c = booking.guest_count__c,
            lead_rotation_group__c = 'National Event'
        );
    
        insert inq;
        return inq.Id;
    }

    // Validate mandatory field length
    public static String checkFieldLength(String text, Integer maxLength){
        if (text != null){
            text = text.substring(0, text.length() > maxLength ? maxLength : text.length());
        }

        //return concatenated string
        return text;
    }
    
    /**
     * Serialize the given records using the default configuration (see SerializeConfig.auto)
     **/
    public static String serialize(Set<Id> ids)
    {
        // Serialize based on no prior knowledge of the objects
        if(ids==null || ids.size()==0)
            throw new SerializerException('List of Ids cannot be null or empty.');
        
        //Map Containing strategy By SObjectType of Ids 
        Map <Schema.SObjectType,SerializeConfig> strategyBySObjectType = new Map <Schema.SObjectType,SerializeConfig>();
    
        for(Id idRecord : ids)
        {
            Schema.SObjectType sObjectType = idRecord.getSObjectType();
            if(strategyBySObjectType.get(sObjectType)==null)
            {
                strategyBySObjectType.put(sObjectType,new SerializeConfig().auto(idRecord.getSObjectType()));
            }
        }
        
        return serialize(ids,strategyBySObjectType);
    }
    
    /**
     * Serialize the given records using the given configuration
     **/
    public static String serialize(Set<Id> ids, SerializeConfig strategy)
    {
        return serialize(ids, new Map<Schema.SObjectType, SerializeConfig> { new List<Id>(ids)[0].getSObjectType() => strategy });
    }

    /**
     * Serialize the given records using the given configurationMap
     **/
    public static String serialize(Set<Id> ids, Map <Schema.SObjectType,SerializeConfig> strategyBySObjectType)
    {           
        // Validate parameters
        if(ids==null || ids.size()==0)
            throw new SerializerException('List of Ids cannot be null or empty.');
            
        // Container to bundle record sets into 
        RecordsBundle recordsToBundle = new RecordsBundle();
        recordsToBundle.recordSetBundles = new List<RecordSetBundle>();     
        recordsToBundle.recordSetBundlesByType = new Map<String, RecordSetBundle>();
        
        // Begin recursive serialize from given records through to related records
        
        //Map containing Key as SObjectType and Value as set of Id's having same SObjectType as key
        Map <Schema.SObjectType,Set<Id>> recordMapToSerialize = new Map <Schema.SObjectType,Set<Id>>();
        for(Id idRecord : ids)
        {
            Schema.SObjectType sObjectType = idRecord.getSObjectType();
            if(recordMapToSerialize.get(sObjectType)!=null)
            {
                recordMapToSerialize.get(sObjectType).add(idRecord);
            }
            else
            {
                Set<Id> idSet = new Set<Id>();
                idSet.add(idRecord);
                recordMapToSerialize.put(sObjectType,idSet);
            }
        }
        Map<String,Set<Id>> processedIds = new Map<String,Set<Id>>();
        Map<Id, SObject> recordsSerialized = new Map<Id, Sobject>();
        Set<Schema.SObjectType> sObjectTypeSet = recordMapToSerialize.keySet();
        for(Schema.SObjectType sobjectTypes : sObjectTypeSet)
        {
            serialize(recordMapToSerialize.get(sobjectTypes), sobjectTypes, null, strategyBySObjectType.get(sobjectTypes), 0, 0, recordsToBundle, new Set<Id>());
        }       

        // Add in a map of record types
        recordsToBundle.setRecordTypeMap();

        // Serialise the records bundle container       
        return JSON.serialize(recordsToBundle);             
    }

    public class DeserializeResponse{
        public Set<String> records;
        public Set<String> exceptions;
        public String results;

        public DeserializeResponse(){
        }
    }

    /**
     * Deserialize the given JSON record set bundle
     **/
    public static DeserializeResponse deserialize(String recordsBundleAsJSON)
    {
        return deserialize(recordsBundleAsJSON, null);
    }
        
    /**
     * Deserialize the given JSON record set bundle utilising the given callback
     **/
    public static DeserializeResponse deserialize(String recordsBundleAsJSON, IDeserializeCallback callback)
    {
        // Desearialise the records bundle
        RecordsBundle recordsBundle = (RecordsBundle) 
            JSON.deserialize(recordsBundleAsJSON, SObjectDataLoader.RecordsBundle.class);
        
        // Get current record types that are in the bundle and see if they exist in the current database
        Map<String, RecordType> currentRecordTypeMap = new Map<String, RecordType>();
        for (RecordType rt : [SELECT Id, Description, DeveloperName, Name, SobjectType FROM RecordType]) {
            currentRecordTypeMap.put(rt.SObjectType + '.' + rt.DeveloperName, rt);
        } 

        // Create a map from imported record type IDs to new ones
        Map<Id, Id> recordTypeIdMap = new Map<Id, Id>();
        if (recordsBundle.recordTypeMap != null) {
            for (RecordType rt : recordsBundle.recordTypeMap.values()) {
                // Get the current record type that matches the imported one
                RecordType currentRecordType = currentRecordTypeMap.get(rt.SObjectType + '.' + rt.DeveloperName);
            
                // Add this to the map
                recordTypeIdMap.put(rt.Id, currentRecordType.Id);
            
            }
        } 

        Set<Id> recordsIds = new Set<Id>();
        // Map to track original ID's against the new SObject record instances being inserted
        Map<Id, SObject> recordsByOriginalId = new Map<Id, SObject>();
        if(omitClonesIdsJSON!=null && !omitClonesIdsJSON.isEmpty()){
            recordsByOriginalId.putAll([SELECT Id FROM Account WHERE Id IN : omitClonesIdsJSON]);
            recordsByOriginalId.putAll([SELECT Id FROM Contact WHERE Id IN : omitClonesIdsJSON]);
            recordsByOriginalId.putAll([SELECT Id FROM User WHERE Id IN : omitClonesIdsJSON]);
        }
        
        // Record set bundles are already ordered in dependency order due to serialisation approach
        Map<String, Schema.SObjectType> sObjectsByType = Schema.getGlobalDescribe();
        List<UnresolvedReferences> unresolvedReferencesByRecord = new List<UnresolvedReferences>(); 
        Set<String> exceptions = new Set<String>();

        for(RecordSetBundle recordSetBundle : recordsBundle.recordSetBundles)
        {
            // List of records to be inserted after de-serialization
            List<Sobject> recordsToInsert = new List<Sobject>();
            // Determine lookup / relationship fields to update prior to inserting these records
            Schema.SObjectType sObjectType = sObjectsByType.get(recordSetBundle.ObjectType);
            Map<String, Schema.SObjectField> sObjectFields;
            sObjectFields = sObjectType.getDescribe().fields.getMap();
            List<Schema.SObjectField> relationshipsFields = new List<Schema.SObjectField>();
            //adding selfrefernce Fields in set 
            Set<String> selfReferenceFields = new Set<String>();

            // Unresolved refrences list for callback
            List<UnresolvedReferences> callbackUnresolvedReferencesList= new List<UnresolvedReferences>(); 
            for(Schema.SObjectField sObjectField : sObjectFields.values())
            {
                if(sObjectField.getDescribe().getType() == Schema.DisplayType.Reference && !sObjectField.getDescribe().getName().equalsIgnoreCase('RecordTypeId')) {
                    relationshipsFields.add(sObjectField);                  
                }
                    
                for(Schema.sObjectType referenceToType : sObjectField.getDescribe().getReferenceTo())
                {                   
                    if(referenceToType.getDescribe().getName().equals(sObjectType.getDescribe().getName()))
                    {
                        selfReferenceFields.add(sObjectField.getDescribe().getName());
                    }
                }
                    
            }
            // Prepare records for insert
            for(SObject originalRecord : recordSetBundle.Records)
            {
                // Update the record type ID if this object supports record types
                if (sObjectFields.containsKey('recordtypeid')) {
                    if (originalRecord.get('RecordTypeId') != null) {
                        // Get the new record type Id 
                        id newRecordTypeId = recordTypeIdMap.get((Id)originalRecord.get('RecordTypeId'));   
                        
                        // Update the record with the new Id
                        originalRecord.put('RecordTypeId', newRecordTypeId);    
                            
                    }
                }

                // Clone the deserialised SObject to remove the original Id prior to inserting it
                SObject newRecord = originalRecord.clone().clone();
                if(recordsByOriginalId.get(originalRecord.Id)==null){
                    // Map the new cloned record to its old Id (once inserted this can be used to obtain the new id)
                    recordsByOriginalId.put(originalRecord.Id, newRecord);
                    if(relationshipsFields.size()>0)
                    {
                        Set<Schema.SObjectField> filteredUnresolvedFieldReferences = new Set<Schema.SObjectField>();
                        Set<Schema.SObjectField> allUnresolvedFieldReferences = new Set<Schema.SObjectField>(); 
                        updateReferenceFieldsInRecords(relationshipsFields,filteredUnresolvedFieldReferences,recordsByOriginalId,originalRecord,allUnresolvedFieldReferences);
                    // Retain a list of records with unresolved references
                        if(allUnresolvedFieldReferences.size()>0)
                        {
                            if(callback!=null)
                            {
                                UnresolvedReferences unresolvedReferences = new UnresolvedReferences();
                                unresolvedReferences.Record = newRecord;
                                unresolvedReferences.References = allUnresolvedFieldReferences;
                                callbackUnresolvedReferencesList.add(unresolvedReferences);
                            }
                            else if(filteredUnresolvedFieldReferences.size()>0)
                            {
                                UnresolvedReferences unresolvedReferences = new UnresolvedReferences();
                                unresolvedReferences.Record = originalRecord;
                                unresolvedReferences.References = filteredUnresolvedFieldReferences;
                                unresolvedReferencesByRecord.add(unresolvedReferences);
                            }
                        }
                        if(filteredUnresolvedFieldReferences.isEmpty() && callback==null)
                        {
                            recordsToInsert.add(newRecord);
                        }   
                    }
                    else
                    {
                        recordsToInsert.add(newRecord);
                    }
                }
            }           
            List<UnresolvedReferences> newUnResolvedReferenceList = new List<UnresolvedReferences>();
            // Let the caller attempt to resolve any references the above could not
            if(callback!=null && callbackUnresolvedReferencesList.size()>0)
            {
                callback.unresolvedReferences(sObjectType, callbackUnresolvedReferencesList);
                for(UnresolvedReferences callBackUnresolvedReference : callbackUnresolvedReferencesList)
                {
                        recordsToInsert.add(callBackUnresolvedReference.Record);
                }
            }

            try{
                // before records insert flush the fields
                for(sObject sObj:recordsToInsert){
                    flushFields(sObj);
                }
                
                insert recordsToInsert;

                for(sObject sObj:recordsToInsert){
                    recordsIds.add(sObj.Id);
                }

            }catch(Exception ex){
                exceptions.add(ex.getMessage());
            }

            recordSetBundle.Records = recordsToInsert;
            processUnresolvedRecords(unresolvedReferencesByRecord, recordsByOriginalId);
        }

        
        if(unresolvedReferencesByRecord.size() > 0)
        {
            List<Sobject> unresolvedRecordsToInsert = new List<Sobject>();
            for(UnresolvedReferences unresolvedReference : unresolvedReferencesByRecord)
            {
                unresolvedRecordsToInsert.add(recordsByOriginalId.get(unresolvedReference.Record.Id));
            }
            
            try{
                // before records insert flush the fields
                for(sObject sObj:unresolvedRecordsToInsert){
                    flushFields(sObj);
                }
                insert unresolvedRecordsToInsert;

                for(sObject sObj:unresolvedRecordsToInsert){
                    recordsIds.add(sObj.Id);
                }
            }catch(Exception ex){
                exceptions.add(ex.getMessage());
            }
           
        }

        DeserializeResponse resp = new DeserializeResponse();
        
        // Return Id list from the bundle set and all unresolved ids
        Set<Id> insertedIds = new Set<Id>();
        
        resp.results = 'success';

        for(RecordSetBundle recordSetBundle : recordsBundle.recordSetBundles){
            for(sObject sObj:recordSetBundle.Records){
                if(sObj.Id != null){
                    insertedIds.add(sObj.Id);
                }
            }
        }
        
        if(!recordsIds.isEmpty()){
            insertedIds.addAll(recordsIds);
            resp.records = (Set<String>)JSON.deserialize(JSON.serialize(insertedIds), Set<String>.class);
        }
        
        if(!exceptions.isEmpty()){
            resp.exceptions = new Set<String>();
            for(String ex : exceptions){
                resp.exceptions.add(ex);
            }
            resp.results = 'failure';
        }

        return resp;
    }
    
    /*
    *  Method to Update foreign key references / lookups / master-detail relationships
    */
    private static void updateReferenceFieldsInRecords(List<Schema.SObjectField> relationshipsFields,Set<Schema.SObjectField> filteredUnresolvedFieldReferences,Map<Id, SObject> recordsByOriginalId,Sobject orignalRecord,Set<Schema.SObjectField> allUnresolvedFieldReferences)
    {
        for(Schema.SObjectField sObjectField : relationshipsFields)
        {                           
            // Obtained original related record Id and search map over new records by old Ids
            Id oldRelatedRecordId = (Id) orignalRecord.get(sObjectField);
            if(oldRelatedRecordId!=null )
            {
                SObject newRelatedRecord = recordsByOriginalId.get(oldRelatedRecordId);
                Sobject newRecord ;
                if(newRelatedRecord!=null && newRelatedRecord.Id!=null)
                {
                    newRecord = recordsByOriginalId.get(orignalRecord.ID);
                    newRecord.put(sObjectField, newRelatedRecord.Id);
                }
                else
                {
                    filteredUnresolvedFieldReferences.add(sObjectField);
                }
            }
            else if(allUnresolvedFieldReferences!=null)
            {
                allUnresolvedFieldReferences.add(sObjectField);
            }
        }
            if(allUnresolvedFieldReferences!=null)
            {
                allUnresolvedFieldReferences.addAll(filteredUnresolvedFieldReferences);
            }
    }

    /*
    *  Method to process unresolved references
    */
    private static void  processUnresolvedRecords(List<UnresolvedReferences> unresolvedReferencesByRecord,Map<Id, SObject> recordsByOriginalId)
    {
    
        List<UnresolvedReferences> unresolvedReferences = new List<UnresolvedReferences>(); 
        Integer recordsSize = unresolvedReferencesByRecord.size();
        if(recordsSize >0)
        {
            List<Sobject> insertResolvedRecords = new List<Sobject>();
            for(UnresolvedReferences filteredReference : unresolvedReferencesByRecord)
            {
                List <Schema.SObjectField> referenceFields = new List<Schema.SObjectField>(filteredReference.References);
                Set<Schema.SobjectField> filteredreferenceFields = new Set<Schema.SobjectField>();
                Sobject oldRecord = filteredReference.Record;
                SObject unprocessedRecord = recordsByOriginalId.get(oldRecord.Id);
                updateReferenceFieldsInRecords(referenceFields, filteredreferenceFields, recordsByOriginalId, oldRecord,null);
                if(filteredreferenceFields.size() >0)
                {
                     filteredReference.References = filteredreferenceFields;
                     unresolvedReferences.add(filteredReference);
                }
                else
                {
                     insertResolvedRecords.add(unprocessedRecord);
                }
            }
            unresolvedReferencesByRecord.clear();
            unresolvedReferencesByRecord.addAll(unresolvedReferences);

            if(insertResolvedRecords.size()>0)
            {

                for(sObject sObj:insertResolvedRecords){
                    flushFields(sObj);
                }

                insert insertResolvedRecords;
                processUnresolvedRecords(unresolvedReferencesByRecord,recordsByOriginalId);
            }       
        }
    }

    /**
     * @description This serialises a set of record and related records from a given set of IDs
     * @param Set<Id> The set of IDs of the main records that should be serialized
     * @param Schema.SObjectType The sObject type that is being serialised
     * @param SerializeConfig Configuration object that controls which relationships etc should be processed
     * @param Integer The current lookup depth. This is incremented for each recurssion that looks at lookup links and is used to prevent infinate loops
     * @param Integer The current child depth. This is incremented for each recurssion that looks at related child records links and is used to prevent infinate loops
     * @param RecordsBundle The bundle of records that is being added to
     * @param Set<Id> A set of record IDs that have already been serialised
     **/
    private static void serialize(Set<ID> ids, Schema.SObjectType sObjectType, Schema.SObjectField queryByIdField, SerializeConfig config, Integer lookupDepth, Integer childDepth, RecordsBundle recordsToBundle, Set<Id> processedIds)
    {       
        // Config?
        if(config==null)
            throw new SerializerException('Must pass a valid SerializeConfig instance.');
        
        // Stop infinite recursion
        if(lookupDepth == config.maxLookupDepth) {
            throw new PreventInfinityLoopException('Maximum Referencing field depth of ' + config.maxLookupDepth + ' is reached');
        }
        else if(childDepth == config.maxChildDepth) {
            throw new PreventInfinityLoopException('Maximum Child reference depth of ' + config.maxChildDepth + ' is reached');
        }
            
        // Describe object and determine fields to serialize
        Schema.DescribeSObjectResult sObjectDesc = sObjectType.getDescribe();

        // Check that these records have not already been processed
        if (queryByIdField == null) {
            ids.removeAll(processedIds);
        }
        processedIds.addAll(ids);
        if (ids.size() == 0) return;        

        //updating so that the we dont query for objects that cannot be queried:-
        if(!sObjectDesc.queryable || !sObjectDesc.isCreateable()) return;
        Map<String, Schema.SObjectField> sObjectFields = config.objectFieldDescribeMap.get(sObjectType);
        if (sObjectFields == null)
        {
            sObjectFields = sObjectDesc.fields.getMap();
            config.objectFieldDescribeMap.put(sObjectType, sObjectFields);
        }
        List<Schema.SObjectField> sObjectFieldsToSerialize = listFieldsToSerialize(sObjectFields, config);
                        
        // Query records to serialize
        String fieldList = null;
        for(Schema.SObjectField sObjectField : sObjectFieldsToSerialize)
            fieldList = fieldList == null ? sObjectField.getDescribe().getName() : fieldList + ',' + sObjectField.getDescribe().getName();
        String query = String.format('select {0} from {1} where {2} in :ids order by {2}', 
            new List<String> { fieldList, sObjectDesc.getName(), queryByIdField == null ? 'id' : queryByIdField.getDescribe().getName(), 'Name' });
        Map<Id, SObject> recordsToSerializeById = new Map<Id, SObject>(Database.query(query));
        if(recordsToSerializeById.size()==0)
            return;
        
        // Any lookup relationships to folow?
        Set<Schema.SObjectField> sObjectFollowRelationships = config.followRelationships.clone();
        sObjectFollowRelationships.retainAll(sObjectFields.values());
        if(sObjectFollowRelationships.size()>0)
        {               
            // Build list of ID's for each related record
            Map<Schema.DescribeFieldResult, Set<Id>> relationshipsByField = new Map<Schema.DescribeFieldResult, Set<Id>>(); 
            for(Schema.SObjectField sObjectField : sObjectFollowRelationships)
                relationShipsByField.put(sObjectField.getDescribe(), new Set<Id>() );           
            for(SObject recordToSerialize : recordsToSerializeById.values())
            {
                for(Schema.DescribeFieldResult relationshipField : relationshipsByField.keySet())
                {
                    Id relatedId = (Id) recordToSerialize.get(relationshipField.getSObjectField());
                    if(relatedId!=null)
                        relationshipsByField.get(relationshipField).add(relatedId);
                }
            }
            // Serialise related records
            for(Schema.DescribeFieldResult relationshipField : relationshipsByField.keySet())
            {
                Set<Id> relatedRecordIds = relationshipsByField.get(relationshipField);
                if(relatedRecordIds.size()>0)
                    serialize(relatedRecordIds, relationshipField.getReferenceTo()[0], null, config, lookupDepth+1, childDepth, recordsToBundle, processedIds);                 
            }
        }
                    
        // Add records to applicable record set bundle
        RecordSetBundle recordSetBundle = recordsToBundle.recordSetBundlesByType.get(sObjectDesc.getName());
        if(recordSetBundle!=null)
        {
            recordSetBundle.Records.addAll(recordsToSerializeById.values());
        }
        else if(recordSetBundle==null)
        {
            recordSetBundle = new RecordSetBundle();
            recordSetBundle.ObjectType = sObjectDesc.getName();
            recordSetBundle.Records = recordsToSerializeById.values();
            recordsToBundle.recordSetBundles.add(recordSetBundle);
            recordsToBundle.recordSetBundlesByType.put(recordSetBundle.ObjectType, recordSetBundle);
        }
                
        // Any child relationships to follow?
        List<Schema.ChildRelationship> childRelationships = sObjectDesc.getChildRelationships();
        for(Schema.ChildRelationship childRelationship : childRelationships)
        { 
            // Is this a child relationship we have been asked to follow?
            Schema.SObjectType childSObjectType = childRelationship.getChildSObject();
            if(config.followChildRelationships.contains(childRelationship.getField()))
                serialize(recordsToSerializeById.keySet(), childSObjectType, childRelationship.getField(), config, lookupDepth, childDepth+1, recordsToBundle, processedIds);
        }
    }
    
    private static List<Schema.SObjectField> listFieldsToSerialize(Map<String, Schema.SObjectField> sObjectFields, SerializeConfig config)
    {
        // Filter fields to serialise
        List<Schema.SObjectField> serializeFields = new List<Schema.SObjectField>(); 
        List<String> fieldNames = new List<String>(sObjectFields.keySet());
        fieldNames.sort();
        for(String fieldName : fieldNames)
        {
            // Skip fields indicated in config
            Schema.SObjectField sObjectField = sObjectFields.get(fieldName);
            if(config.omitFields!=null && config.omitFields.contains(sObjectField))
                continue;
            // Skip read only fields, such as auto numbers and formula fields
            Schema.DescribeFieldResult sObjectFieldDescribe = sObjectField.getDescribe();
            if(sObjectFieldDescribe.isAutoNumber() ||
               sObjectFieldDescribe.isCalculated())
               continue;    
            // Skip lookup fields not in either of the follow lists
            if(sObjectFieldDescribe.getType() == Schema.DisplayType.Reference)
                if(!(config.followRelationships.contains(sObjectField) ||
                     config.keepRelationshipValues.contains(sObjectField) || 
                     config.followChildRelationships.contains(sObjectField)))
                   continue;
            // Serialize this field..                       
            serializeFields.add(sObjectField);
        }           
        return serializeFields; 
    }
    
    /*
    * Method to create a Map from json file
    */
    public static Map<String,List<Sobject>> deserializedRecords(String recordsBundleAsJSON)
    {
        Map<String,List<Sobject>> recordBundleMap = new Map<String,List<Sobject>>();
        RecordsBundle recordsBundle = (RecordsBundle) 
            JSON.deserialize(recordsBundleAsJSON, SObjectDataLoader.RecordsBundle.class);
        for(RecordSetBundle recordSetBundle : recordsBundle.recordSetBundles)
        {
            List<Sobject> recordList = new List<Sobject>();
            if(recordBundleMap.get(recordSetBundle.ObjectType)!= null)
                recordList.addAll(recordBundleMap.get(recordSetBundle.ObjectType));
            else
                recordList.addAll(recordSetBundle.Records);
            recordBundleMap.put(recordSetBundle.ObjectType, recordList);
        }
        return recordBundleMap; 
    }
    
    /** 
     * General exception class
     **/
    public class SerializerException extends Exception
    {
        
    }
    
    /**
     * Callback used during deserialization
     **/
    public interface IDeserializeCallback
    {
        /**
         * Used during deserialization to allow caller to attempt to resolve references not resolved but required to insert records
         **/
        void unresolvedReferences(Schema.SObjectType sObjectType, List<UnresolvedReferences> unresolvedReferences);
    }
    
    /**
     * Used during deserialization to allow caller to attempt to resolve references not resolved but required to insert records
     **/
    public class UnresolvedReferences
    {
        public SObject Record;
        public Set<Schema.SObjectField> References;
    }
    
    /**
     * Internal Apex represnetation of the serialized output for all recordsets
     **/
    private class RecordsBundle
    {
        // Order of bundle sets is important
        public List<RecordSetBundle> RecordSetBundles;          
        // Used by serialiser to group records by type during recursion
        public transient Map<String, RecordSetBundle> RecordSetBundlesByType;

        // Record type map by Ids
        public Map<Id, RecordType> recordTypeMap;
        
        /**
         * @description Create a map of the current record types for all of the included records
         **/ 
        public void setRecordTypeMap() {
    
            // Describe object and determine fields to serialize
            Map<String,Schema.SObjectType> globalDesc = Schema.getGlobalDescribe();
            
            // Build up a set of record type IDs
            Set<Id> recordTypeIds = new Set<Id>();
            for (RecordSetBundle bundle : RecordSetBundles) {
                // Get a map of fields
                SObjectType accountType = globalDesc.get(bundle.ObjectType);
                Map<String,Schema.SObjectField> mfields = accountType.getDescribe().fields.getMap();                
                
                // If this object contains a record type then step through and get the IDs
                if (mfields.containsKey('recordtypeid')) {
                    for (SObject obj : bundle.Records) {
                        if (obj.get('RecordTypeId') != null) {
                            recordTypeIds.add((id)obj.get('RecordTypeId'));
                        }
                    }                   
                }

            }
            
            // Get all of the record types that are included
            recordTypeMap = new Map<Id, RecordType>([SELECT Id, Description, DeveloperName, Name, SobjectType FROM RecordType WHERE Id=:recordTypeIds]);
                        
        }       
    }
    
    /**
     * Internal Apex represnetation of the serialized output for a given recordset
     **/
    private class RecordSetBundle
    {
        // Groups records by type
        public String ObjectType;
        public List<SObject> Records;   
    }
    
    /**
     * Exception thrown in case the max depth for relationships is reached
     **/
    public class PreventInfinityLoopException extends Exception{}
}