@isTest
public class UserHistorySearchControllerTest {
    
    // Test data setup
    @TestSetup
    static void setupTestData() {
        // Create test users with unique usernames using timestamp
        List<User> testUsers = new List<User>();
        
        // Create a test user profile (you may need to adjust this based on your org)
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        
        // Generate unique usernames using current timestamp
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        User testUser1 = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testuser1@test.com',
            Username = 'testuser1' + timestamp + '@test.com.unique',
            Alias = 'tuser1',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = testProfile.Id
        );
        
        User testUser2 = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser2@test.com',
            Username = 'testuser2' + timestamp + '@test.com.unique',
            Alias = 'tuser2',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = testProfile.Id
        );
        
        testUsers.add(testUser1);
        testUsers.add(testUser2);
        insert testUsers;
        
        // Create test User_History__c records
        List<User_History__c> historyRecords = new List<User_History__c>();
        
        User_History__c history1 = new User_History__c(
            User__c = testUsers[0].Id,
            Changed_By__c = testUsers[1].Id,
            Changed_Field__c = 'Email',
            Old_Value__c = 'old@test.com',
            New_Value__c = 'new@test.com',
            Date__c = Date.today(),
            Changed_Time__c = Time.newInstance(10, 30, 0, 0)
        );
        
        User_History__c history2 = new User_History__c(
            User__c = testUsers[1].Id,
            Changed_By__c = testUsers[0].Id,
            Changed_Field__c = 'Phone',
            Old_Value__c = '1234567890',
            New_Value__c = '0987654321',
            Date__c = Date.today().addDays(-1),
            Changed_Time__c = Time.newInstance(14, 15, 30, 0)
        );
        
        User_History__c history3 = new User_History__c(
            User__c = testUsers[0].Id,
            Changed_By__c = testUsers[1].Id,
            Changed_Field__c = 'Department',
            Old_Value__c = 'Sales',
            New_Value__c = 'Marketing',
            Date__c = Date.today().addDays(-2),
            Changed_Time__c = Time.newInstance(9, 0, 0, 0)
        );
        
        // Test record with null values
        User_History__c history4 = new User_History__c(
            User__c = testUsers[0].Id,
            Changed_By__c = testUsers[1].Id,
            Changed_Field__c = 'Title',
            Old_Value__c = null,
            New_Value__c = 'Manager',
            Date__c = Date.today().addDays(-5),
            Changed_Time__c = null
        );
        
        historyRecords.add(history1);
        historyRecords.add(history2);
        historyRecords.add(history3);
        historyRecords.add(history4);
        insert historyRecords;
    }
    
    @isTest
    static void testSearchHistoryForLWC_AllParameters() {
        // Get test users
        List<User> testUsers = [SELECT Id FROM User WHERE Username LIKE '%@test.com.unique' ORDER BY Username];
        
        Test.startTest();
        
        // Test with all parameters
        List<UserHistorySearchController.HistorySearchResult> results = 
            UserHistorySearchController.searchHistoryForLWC(
                testUsers[0].Id,
                testUsers[1].Id,
                'Email',
                String.valueOf(Date.today()),
                String.valueOf(Date.today()),
                10
            );
        
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should find one matching record');
        System.assertEquals('Email', results[0].changedField, 'Field should match');
        System.assertEquals('old@test.com', results[0].oldValue, 'Old value should match');
        System.assertEquals('new@test.com', results[0].newValue, 'New value should match');
    }
    
    @isTest
    static void testSearchHistoryForLWC_NoParameters() {
        Test.startTest();
        
        // Test with no parameters (should return all records)
        List<UserHistorySearchController.HistorySearchResult> results = 
            UserHistorySearchController.searchHistoryForLWC(
                null, null, null, null, null, null
            );
        
        Test.stopTest();
        
        // Should return all test records
        System.assertEquals(4, results.size(), 'Should return all history records');
    }
    
    @isTest
    static void testSearchHistoryForLWC_PartialParameters() {
        // Get test users
        List<User> testUsers = [SELECT Id FROM User WHERE Username LIKE '%@test.com.unique' ORDER BY Username];
        
        Test.startTest();
        
        // Test with only target user
        List<UserHistorySearchController.HistorySearchResult> results = 
            UserHistorySearchController.searchHistoryForLWC(
                testUsers[0].Id, null, null, null, null, 5
            );
        
        Test.stopTest();
        
        // Should return records for user 1
        System.assertEquals(3, results.size(), 'Should return 3 records for test user 1');
    }
    
    @isTest
    static void testSearchHistoryForLWC_DateRange() {
        Test.startTest();
        
        // Test with date range
        List<UserHistorySearchController.HistorySearchResult> results = 
            UserHistorySearchController.searchHistoryForLWC(
                null, null, null, 
                String.valueOf(Date.today().addDays(-3)),
                String.valueOf(Date.today()),
                100
            );
        
        Test.stopTest();
        
        // Should return records within date range
        System.assertEquals(3, results.size(), 'Should return 3 records within date range');
    }
    
    
    @isTest
    static void testSearchHistoryForLWC_EmptyStrings() {
        Test.startTest();
        
        // Test with empty strings
        List<UserHistorySearchController.HistorySearchResult> results = 
            UserHistorySearchController.searchHistoryForLWC(
                '', '', '', '', '', 50
            );
        
        Test.stopTest();
        
        // Should return all records
        System.assertEquals(4, results.size(), 'Should return all records with empty string parameters');
    }
    
    @isTest
    static void testGetActiveUsers_Success() {
        Test.startTest();
        
        List<Map<String, String>> users = UserHistorySearchController.getActiveUsers();
        
        Test.stopTest();
        
        // Should return active users
        System.assertNotEquals(null, users, 'Users list should not be null');
        System.assert(users.size() > 0, 'Should return at least some users');
        
        // Check structure of returned data
        for (Map<String, String> user : users) {
            System.assert(user.containsKey('value'), 'User should have value key');
            System.assert(user.containsKey('label'), 'User should have label key');
        }
    }
    
    @isTest
    static void testGetTrackedFields_Success() {
        Test.startTest();
        
        List<Map<String, String>> fields = UserHistorySearchController.getTrackedFields();
        
        Test.stopTest();
        
        // Should return tracked fields
        System.assertNotEquals(null, fields, 'Fields list should not be null');
        System.assertEquals(4, fields.size(), 'Should return 4 distinct fields from test data');
        
        // Check structure of returned data
        for (Map<String, String> field : fields) {
            System.assert(field.containsKey('value'), 'Field should have value key');
            System.assert(field.containsKey('label'), 'Field should have label key');
        }
    }
    
    @isTest
    static void testGetUserChangesSummary_WithData() {
        // Get test user
        List<User> testUsers = [SELECT Id FROM User WHERE Username LIKE '%@test.com.unique' ORDER BY Username LIMIT 1];
        
        Test.startTest();
        
        Map<String, Object> summary = UserHistorySearchController.getUserChangesSummary(
            testUsers[0].Id, 30
        );
        
        Test.stopTest();
        
        // Verify summary structure
        System.assertNotEquals(null, summary, 'Summary should not be null');
        System.assert(summary.containsKey('totalChanges'), 'Should contain totalChanges');
        System.assert(summary.containsKey('fieldChanges'), 'Should contain fieldChanges');
        System.assert(summary.containsKey('changerStats'), 'Should contain changerStats');
        System.assert(summary.containsKey('daysPeriod'), 'Should contain daysPeriod');
        
        // Verify data
        Integer totalChanges = (Integer) summary.get('totalChanges');
        System.assertEquals(3, totalChanges, 'Should have 3 total changes for test user');
        
        Integer daysPeriod = (Integer) summary.get('daysPeriod');
        System.assertEquals(30, daysPeriod, 'Days period should be 30');
    }
    
    @isTest
    static void testGetUserChangesSummary_NoData() {
        // Create a user with no history
        Profile testProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String timestamp = String.valueOf(System.currentTimeMillis());
        
        User emptyUser = new User(
            FirstName = 'Empty',
            LastName = 'User',
            Email = 'emptyuser@test.com',
            Username = 'emptyuser' + timestamp + '@test.com.unique',
            Alias = 'empty',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = testProfile.Id
        );
        insert emptyUser;
        
        Test.startTest();
        
        Map<String, Object> summary = UserHistorySearchController.getUserChangesSummary(
            emptyUser.Id, 7
        );
        
        Test.stopTest();
        
        // Verify summary for user with no data
        System.assertNotEquals(null, summary, 'Summary should not be null');
        Integer totalChanges = (Integer) summary.get('totalChanges');
        System.assertEquals(0, totalChanges, 'Should have 0 total changes for empty user');
    }
    
    @isTest
    static void testHistorySearchResult_Constructor() {
        Test.startTest();
        
        // Test wrapper class constructor
        UserHistorySearchController.HistorySearchResult result = 
            new UserHistorySearchController.HistorySearchResult();
        
        Test.stopTest();
        
        // Verify object creation
        System.assertNotEquals(null, result, 'Result object should be created');
    }
    
    @isTest
    static void testHistorySearchResult_PropertyAccess() {
        Test.startTest();
        
        // Test setting and getting properties
        UserHistorySearchController.HistorySearchResult result = 
            new UserHistorySearchController.HistorySearchResult();
        
        result.userId = 'test123';
        result.userName = 'Test User';
        result.changedField = 'Email';
        result.oldValue = 'old@test.com';
        result.newValue = 'new@test.com';
        result.dateChanged = Date.today();
        result.timeChanged = '10:30:00';
        
        Test.stopTest();
        
        // Verify properties
        System.assertEquals('test123', result.userId, 'User ID should match');
        System.assertEquals('Test User', result.userName, 'User name should match');
        System.assertEquals('Email', result.changedField, 'Changed field should match');
        System.assertEquals('old@test.com', result.oldValue, 'Old value should match');
        System.assertEquals('new@test.com', result.newValue, 'New value should match');
        System.assertEquals(Date.today(), result.dateChanged, 'Date should match');
        System.assertEquals('10:30:00', result.timeChanged, 'Time should match');
    }
    
    @isTest
    static void testSearchWithNullTimeValue() {
        Test.startTest();
        
        // This will test the time formatting logic with null values
        List<UserHistorySearchController.HistorySearchResult> results = 
            UserHistorySearchController.searchHistoryForLWC(
                null, null, 'Title', null, null, 10
            );
        
        Test.stopTest();
        
        // Should return the record with null time
        System.assertEquals(1, results.size(), 'Should find record with Title field');
        System.assertEquals('', results[0].timeChanged, 'Time should be empty string for null time');
    }
    
    @isTest
    static void testLimitRecordsZero() {
        Test.startTest();
        
        // Test with limit of 0 (should default to 100)
        List<UserHistorySearchController.HistorySearchResult> results = 
            UserHistorySearchController.searchHistoryForLWC(
                null, null, null, null, null, 0
            );
        
        Test.stopTest();
        
        // Should still return records (using default limit)
        System.assertEquals(4, results.size(), 'Should return all test records');
    }
}