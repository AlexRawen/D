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
 * Test class for SObjectDataLoader
 *
 *   See https://github.com/afawcett/apex-sobjectdataloader for known issues, restrictions and TODO's
 *   Testing : SObjectDataLoader.cls (82% Coverage)   
 **/
@IsTest
private class TestSObjectDataLoader {

    //DATA CREATION

    //Test implemetnation of IDeserializeCallback, automatically applies AccountId to new Opportunity
    private class ApplyAccountRecord implements SObjectDataLoader.IDeserializeCallback
    {
        private Account accRec;
        
        public ApplyAccountRecord()
        {
            accRec = new Account(Name = 'TestAccount1');
            insert accRec;
        }
        
        public void unresolvedReferences(Schema.SObjectType sObjectType, List<SObjectDataLoader.UnresolvedReferences> unresolvedReferences)
        {
            if(sObjectType == Opportunity.sObjectType) // Opportunity object?
                for(SObjectDataLoader.UnresolvedReferences unresolvedReference : unresolvedReferences)
                    if(unresolvedReference.References.contains(Opportunity.AccountId)) // AccountId field?
                        unresolvedReference.Record.put(Opportunity.AccountId, accRec.Id); // Set AccountId
        }       
    }
    

    //Test implemetnation of IDeserializeCallback, automatically applies Standard Pricebook to new PricebookEntry's
    private class ApplyStandardPricebook implements SObjectDataLoader.IDeserializeCallback
    {
        private Id standardPricebookId;
        
        public ApplyStandardPricebook()
        {
            standardPricebookId = Test.getStandardPricebookId();                
        }
        
        public void unresolvedReferences(Schema.SObjectType sObjectType, List<SObjectDataLoader.UnresolvedReferences> unresolvedReferences)
        {
            if(sObjectType == PricebookEntry.sObjectType) // PricebookEntry object?
                for(SObjectDataLoader.UnresolvedReferences unresolvedReference : unresolvedReferences)
                    if(unresolvedReference.References.contains(PricebookEntry.Pricebook2Id)) // Pricebook2Id field?
                        unresolvedReference.Record.put(PricebookEntry.Pricebook2Id, standardPricebookId); // Set Standard Pricebook
        }       
    }
    
    private static Set<ID> createOpportunities()
    {          
        // Insert Opportunities
        List<Opportunity> opps = new List<Opportunity>();
        List<List<Product2>> productsByOpp = new List<List<Product2>>();        
        List<List<PricebookEntry>> pricebookEntriesByOpp = new List<List<PricebookEntry>>();        
        List<List<OpportunityLineItem>> oppLinesByOpp = new List<List<OpportunityLineItem>>();      
        for(Integer o=0; o<10; o++)
        {
            Opportunity opp = new Opportunity();
            opp.Name = 'Test Name ' + o;
            opp.StageName = 'Open';
            opp.CloseDate = System.today();
            opps.add(opp);
            List<Product2> products = new List<Product2>();
            List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
            List<OpportunityLineItem> oppLineItems = new List<OpportunityLineItem>();
            for(Integer i=0; i<o+1; i++)
            {                       
                Product2 product = new Product2();
                product.Name = opp.Name + ' : Product : ' + i;
                products.add(product);
                PricebookEntry pbe = new PricebookEntry();
                pbe.UnitPrice = 10;
                pbe.IsActive = true;
                pbe.UseStandardPrice = false;
                pbe.Pricebook2Id = Test.getStandardPricebookId();
                pricebookEntries.add(pbe);
                OpportunityLineItem oppLineItem = new OpportunityLineItem();
                oppLineItem.Quantity = 1;
                oppLineItem.TotalPrice = 10;
                oppLineItems.add(oppLineItem);
            }
            productsByOpp.add(products);
            pricebookEntriesByOpp.add(pricebookEntries);
            oppLinesByOpp.add(oppLineItems);                
        }
        // Insert Opportunities
        insert opps;
        // Insert Products
        List<Product2> allProducts = new List<Product2>(); 
        for(List<Product2> products : productsByOpp)
        {
            allProducts.addAll(products);           
        }
        insert allProducts;
        // Insert Pricebooks
        Integer oppIdx = 0;         
        List<PricebookEntry> allPricebookEntries = new List<PricebookEntry>();              
        for(List<PricebookEntry> pricebookEntries : pricebookEntriesByOpp)
        {
            List<Product2> products = productsByOpp[oppIdx++];
            Integer lineIdx = 0;
            for(PricebookEntry pricebookEntry : pricebookEntries)
            {
                pricebookEntry.Product2Id = products[lineIdx++].Id;
            }
            allPricebookEntries.addAll(pricebookEntries);
        }           
        insert allPricebookEntries;
        // Insert Opportunity Lines
        oppIdx = 0;                     
        List<OpportunityLineItem> allOppLineItems = new List<OpportunityLineItem>();            
        for(List<OpportunityLineItem> oppLines : oppLinesByOpp)
        {
            List<PricebookEntry> pricebookEntries = pricebookEntriesByOpp[oppIdx];
            Integer lineIdx = 0;
            for(OpportunityLineItem oppLine : oppLines)
            {
                oppLine.OpportunityId = opps[oppIdx].Id;
                oppLine.PricebookEntryId = pricebookEntries[lineIdx++].Id;
            }
            allOppLineItems.addAll(oppLines);
            oppIdx++;
        }           
        insert allOppLineItems;     
        return new Map<Id, Opportunity>(opps).keySet();         
    }
    
    private static void assertResults(Set<String> opportunityIds)
    {
        List<Opportunity> opportunities = 
            [select Id, Name, Amount, 
                (select id, PricebookEntry.Product2.Name, PricebookEntry.Pricebook2Id, UnitPrice 
                 from OpportunityLineItems 
                 order by PricebookEntry.Product2.Name) 
                from Opportunity 
                where Id in :opportunityIds 
                order by Name];     
    }

    //UNIT TESTS

    @IsTest public static void testManuallyConfigured()
    {               
        // Save point to rollback test data
        System.Savepoint savePoint = Database.setSavepoint();
        
        // Serialise test data into JSON record set bundle via manual configuration
        String serializedData = SObjectDataLoader.serialize(createOpportunities(), 
            new SObjectDataLoader.SerializeConfig().
                keepValue(Product2.RecordTypeId).
                    followChild(OpportunityLineItem.OpportunityId).     // Serialize any related OpportunityLineItem's (children)
                        follow(OpportunityLineItem.PricebookEntryId).   // Serialize any related PricebookEntry's
                            follow(PricebookEntry.Product2Id).          // Serialize any related Products's
                                omit(OpportunityLineItem.UnitPrice));   // Do not serialize the UnitPrice, as TotalPrice is enough and both cannot exist together
                    
        // Rollback test data
        Database.rollback(savePoint);
        
        // Recreate test data via deserialize
        SObjectDataLoader.DeserializeResponse result = SObjectDataLoader.deserialize(serializedData);
        assertResults(result.records);
    }
    
    @IsTest public static void testAutoConfigured()
    {
        // Save point to rollback test data
        System.Savepoint savePoint = Database.setSavepoint();
        Account testAcc = new Account(Name = 'TestAccount');
        insert testAcc;
        Opportunity opp = new Opportunity();
        opp.Name = 'TestOpp' ;
        opp.StageName = 'Open';
        opp.CloseDate = System.today();
        opp.AccountId = testAcc.Id;
        insert opp;
        // Serialise test data into JSON record set bundle via auto configuraiton (with some manual tweaks)
        String serializedData = SObjectDataLoader.serialize(new Set<Id>{opp.Id},
            new SObjectDataLoader.SerializeConfig().
                auto(Opportunity.sObjectType). // Automatically determine child and related object references needed (calls follow methods)
                omit(Opportunity.AccountID));       

        // Rollback test data
        Database.rollback(savePoint);
        
        // Recreate test data via deserialize
        SObjectDataLoader.DeserializeResponse result = SObjectDataLoader.deserialize(serializedData);

        //Verify that opportunit record was recreated and account was skipped
        System.assertEquals(result.records.size(), 1);
    }

    //Without Blacklisting RecordTypeId, the autoconfig serialize/deserialize
    //will try to insert a new RecordType object which throws:
    //'System.TypeException: DML not allowed on RecordType'

    //Test uses dynamic binding to prevent compile-time errors in orgs without RecordTypes enabled
    //Currently, the test method only tests the logic if there are 2+ RecordTypes on the Account object
    //otherwise, the if statement will silently ignore the rest of the testMethod.

    @isTest private static void shouldNotTryToInsertRecordType(){
        List<RecordType> accountRecordTypes = [SELECT Id, DeveloperName FROM RecordType WHERE sObjectType = 'Account' AND isActive = true];
        //Only run this test if there are multiple active recordtypes on Account object
        if (accountRecordTypes.size() > 0){
            List<sObject> testAccounts = new List<Account>();
            for (RecordType aRT : accountRecordTypes){
                sObject testAccount = new Account(Name = 'Test' + aRT.DeveloperName);
                
                //Dynamic binding will prevent any compile time errors if RecordTypeId field doesn't exist
                testAccount.put('RecordTypeId', aRT.Id);
                testAccounts.add(testAccount);
            }
            insert testAccounts;
            Set<Id> newAccountIds = new Set<Id>();
            for (sObject myAccount : testAccounts){
                newAccountIds.add(myAccount.Id);
            }
            String serializedData = SObjectDataLoader.serialize(newAccountIds);
            SObjectDataLoader.DeserializeResponse result = SObjectDataLoader.deserialize(serializedData);
            Set<String> resultIds = result.records;
            
            //Dynamic soql will prevent any compile time errors if RecordTypeId field doesn't exist
            String accountsQuery = 'SELECT Id, RecordTypeId FROM Account WHERE Id IN :newAccountIds';
            testAccounts = Database.query(accountsQuery);
            Set<Id> recordTypeIdsOfNewAccounts = new Set<Id>();

            for (sObject myAccount : testAccounts){
                recordTypeIdsOfNewAccounts.add((Id) myAccount.get('RecordTypeId'));
            }
            system.assertEquals(recordTypeIdsOfNewAccounts.size(), accountRecordTypes.size());
        }
    }

    @isTest private static void deserializingObjectsWithSelfRefernces(){
        Account testParentAccount = new Account(Name = 'ParentAccount');
        insert testParentAccount;
        
        Account childAccount = new Account();
        childAccount.ParentId =testParentAccount.Id;
        childAccount.Name = 'ChildAccount'; 
        insert childAccount;
        
        Set<Id> childAccountIds = new Set<Id>();
        childAccountIds.add(childAccount.Id);
        String serializedData = SObjectDataLoader.serialize(childAccountIds);
        Integer recordsBeforeDeletion = [Select count() from Account];
        List<Account> recordsToDelete =  new List<Account>();
        recordsToDelete.add(testParentAccount);
        recordsToDelete.add(childAccount);
        delete recordsToDelete;
        
        Integer recordsAfterDeletion = [Select count() from Account];
        System.assertEquals(recordsBeforeDeletion,recordsAfterDeletion+2);
        
        SObjectDataLoader.DeserializeResponse result = SObjectDataLoader.deserialize(serializedData);
        Set<String> resultIds = result.records;

        List<Account> recordsAfterDeserialization =[Select Id,Name,ParentId from Account];
        System.assertEquals(recordsBeforeDeletion,recordsAfterDeserialization.size());
        
        Id parentRecordId;
        for(Account acc : recordsAfterDeserialization){
            if('childAccount'.equals(acc.Name)){
                parentRecordId = acc.ParentId;
                break;
            }
        }
        for(Account acc : recordsAfterDeserialization){
            if(parentRecordId!=null && acc.id ==parentRecordId){
                system.assertEquals(acc.Name,'ParentAccount');
                break;
            }
        }
    }
    
    @isTest private static void deserializingObjectsWithSelfReferncesLevel2(){
        //add a ParentAccount
        Account testParentAccount = new Account(Name = 'ParentAccount');
        insert testParentAccount;
        
        //add a child to ParentAccount
        Account childAccount1 = new Account();
        childAccount1.ParentId =testParentAccount.Id;
        childAccount1.Name = 'ChildAccount1';   
        insert childAccount1;
        
        //Create Bundle with childAccount1 as subcomponent
        Set<Id> childAccountIds = new Set<Id>();
        childAccountIds.add(childAccount1.Id);
        //Records are exported
        String serializedData = SObjectDataLoader.serialize(childAccountIds);
        
        Integer recordsBeforeDeletion = [Select count() from Account];
        List<Account> recordsToDelete =  new List<Account>();
        recordsToDelete.add(testParentAccount);
        recordsToDelete.add(childAccount1);
        delete recordsToDelete;
        
        Integer recordsAfterDeletion = [Select count() from Account];
        system.assertEquals(recordsBeforeDeletion,recordsAfterDeletion+2);
        
        //Importing Records
        SObjectDataLoader.DeserializeResponse result = SObjectDataLoader.deserialize(serializedData);
        Set<String> resultIds = result.records;
        List<Account> recordsAfterDeserialization =[Select Id,Name,ParentId from Account];
        system.assertEquals(recordsBeforeDeletion,recordsAfterDeserialization.size());
    }
}