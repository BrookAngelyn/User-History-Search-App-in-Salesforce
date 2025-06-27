public class UserHistorySearchController {
    
    /**
     * Wrapper class for search results
     */
    public class HistorySearchResult {
        @AuraEnabled public String userId { get; set; }
        @AuraEnabled public String userName { get; set; }
        @AuraEnabled public String changedBy { get; set; }
        @AuraEnabled public String changedByName { get; set; }
        @AuraEnabled public String changedField { get; set; }
        @AuraEnabled public String oldValue { get; set; }
        @AuraEnabled public String newValue { get; set; }
        @AuraEnabled public Date dateChanged { get; set; }
        @AuraEnabled public String timeChanged { get; set; }
        @AuraEnabled public String recordId { get; set; }
        
        public HistorySearchResult() {}
    }
    
    /**
     * Search user history records based on filters
     */
    public static List<HistorySearchResult> searchUserHistory(
        String targetUserId, 
        String changedByUserId, 
        String fieldName,
        Date startDate,
        Date endDate,
        Integer limitRecords
    ) {
        List<HistorySearchResult> results = new List<HistorySearchResult>();
        
        // Build dynamic SOQL query
        String query = 'SELECT Id, User__c, User__r.Name, Changed_By__c, Changed_By__r.Name, ' +
                      'Changed_Field__c, Old_Value__c, New_Value__c, Date__c, Changed_Time__c ' +
                      'FROM User_History__c WHERE Id != null';
        
        List<String> conditions = new List<String>();
        Map<String, Object> bindVars = new Map<String, Object>();
        
        // Add filters based on provided parameters
        if (String.isNotBlank(targetUserId)) {
            conditions.add('User__c = :targetUserId');
            bindVars.put('targetUserId', targetUserId);
        }
        
        if (String.isNotBlank(changedByUserId)) {
            conditions.add('Changed_By__c = :changedByUserId');
            bindVars.put('changedByUserId', changedByUserId);
        }
        
        if (String.isNotBlank(fieldName)) {
            conditions.add('Changed_Field__c = :fieldName');
            bindVars.put('fieldName', fieldName);
        }
        
        if (startDate != null) {
            conditions.add('Date__c >= :startDate');
            bindVars.put('startDate', startDate);
        }
        
        if (endDate != null) {
            conditions.add('Date__c <= :endDate');
            bindVars.put('endDate', endDate);
        }
        
        // Add conditions to query
        if (!conditions.isEmpty()) {
            query += ' AND ' + String.join(conditions, ' AND ');
        }
        
        // Add ordering and limit
        query += ' ORDER BY Date__c DESC, Changed_Time__c DESC';
        
        if (limitRecords != null && limitRecords > 0) {
            query += ' LIMIT ' + limitRecords;
            bindVars.put('limitRecords', limitRecords);
        } else {
            query += ' LIMIT 100'; // Default limit
        }
        
        System.debug('Generated Query: ' + query);
        System.debug('Bind Variables: ' + bindVars);
        
        try {
            // Execute query with bind variables
            List<User_History__c> historyRecords = Database.query(query);
            
            System.debug('Found ' + historyRecords.size() + ' records');
            
            // Convert to wrapper class
            for (User_History__c record : historyRecords) {
                HistorySearchResult result = new HistorySearchResult();
                result.recordId = record.Id;
                result.userId = record.User__c;
                result.userName = record.User__r?.Name;
                result.changedBy = record.Changed_By__c;
                result.changedByName = record.Changed_By__r?.Name;
                result.changedField = record.Changed_Field__c;
                result.oldValue = record.Old_Value__c;
                result.newValue = record.New_Value__c;
                result.dateChanged = record.Date__c;
                
                // Format time properly
                if (record.Changed_Time__c != null) {
                    Time timeValue = record.Changed_Time__c;
                    result.timeChanged = String.valueOf(timeValue);
                } else {
                    result.timeChanged = '';
                }
                
                results.add(result);
                System.debug('Added result: ' + result);
            }
            
        } catch (Exception e) {
            System.debug('Error in searchUserHistory: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error searching user history: ' + e.getMessage());
        }
        
        System.debug('Returning ' + results.size() + ' results');
        return results;
    }
    
    /**
     * Get list of users for dropdown selection
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActiveUsers() {
        List<Map<String, String>> userOptions = new List<Map<String, String>>();
        
        try {
            List<User> users = [
                SELECT Id, Name, Username, Email 
                FROM User 
                WHERE IsActive = true 
                ORDER BY Name 
                LIMIT 1000
            ];
            
            for (User u : users) {
                Map<String, String> userOption = new Map<String, String>();
                userOption.put('value', u.Id);
                userOption.put('label', u.Name + ' (' + u.Username + ')');
                userOptions.add(userOption);
            }
            
        } catch (Exception e) {
            System.debug('Error getting users: ' + e.getMessage());
            throw new AuraHandledException('Error loading users: ' + e.getMessage());
        }
        
        return userOptions;
    }
    
    /**
     * Get list of tracked fields for dropdown
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getTrackedFields() {
        List<Map<String, String>> fieldOptions = new List<Map<String, String>>();
        
        // try {
            // Get distinct field names from history records
            List<AggregateResult> fieldResults = [
                SELECT Changed_Field__c fieldName
                FROM User_History__c 
                WHERE Changed_Field__c != null
                GROUP BY Changed_Field__c
                ORDER BY Changed_Field__c
                LIMIT 200
            ];
            
            for (AggregateResult ar : fieldResults) {
                String fieldName = (String)ar.get('fieldName');
                if (String.isNotBlank(fieldName)) {
                    Map<String, String> fieldOption = new Map<String, String>();
                    fieldOption.put('value', fieldName);
                    fieldOption.put('label', fieldName);
                    fieldOptions.add(fieldOption);
                }
            }
            
        // } catch (Exception e) {
        //     System.debug('Error getting tracked fields: ' + e.getMessage());
        //     throw new AuraHandledException('Error loading fields: ' + e.getMessage());
        // }
        
        return fieldOptions;
    }
    
    /**
     * Lightning Web Component compatible search method
     */
    @AuraEnabled
    public static List<HistorySearchResult> searchHistoryForLWC(
        String targetUserId, 
        String changedByUserId, 
        String fieldName,
        String startDateStr,
        String endDateStr,
        Integer limitRecords
    ) {
        System.debug('searchHistoryForLWC called with parameters:');
        System.debug('targetUserId: ' + targetUserId);
        System.debug('changedByUserId: ' + changedByUserId);
        System.debug('fieldName: ' + fieldName);
        System.debug('startDateStr: ' + startDateStr);
        System.debug('endDateStr: ' + endDateStr);
        System.debug('limitRecords: ' + limitRecords);
        
        Date startDate = null;
        Date endDate = null;
        
        // Parse date strings if provided
        if (String.isNotBlank(startDateStr)) {
            try {
                startDate = Date.valueOf(startDateStr);
                System.debug('Parsed start date: ' + startDate);
            } catch (Exception e) {
                System.debug('Invalid start date format: ' + startDateStr + ', Error: ' + e.getMessage());
            }
        }
        
        if (String.isNotBlank(endDateStr)) {
            // try {
                endDate = Date.valueOf(endDateStr);
                System.debug('Parsed end date: ' + endDate);
            // } catch (Exception e) {
            //     System.debug('Invalid end date format: ' + endDateStr + ', Error: ' + e.getMessage());
            // }
        }
        
        List<HistorySearchResult> results = searchUserHistory(targetUserId, changedByUserId, fieldName, startDate, endDate, limitRecords);
        
        System.debug('searchHistoryForLWC returning ' + results.size() + ' results');
        return results;
    }
    
    /**
     * Get summary statistics for user changes
     */
    @AuraEnabled
    public static Map<String, Object> getUserChangesSummary(String userId, Integer days) {
        Map<String, Object> summary = new Map<String, Object>();
        
        // try {
            Date cutoffDate = Date.today().addDays(-days);
            
            // Total changes for this user
            Integer totalChanges = [
                SELECT COUNT() 
                FROM User_History__c 
                WHERE User__c = :userId AND Date__c >= :cutoffDate
            ];
            
            // Changes by field
            List<AggregateResult> fieldChanges = [
                SELECT Changed_Field__c fieldName, COUNT(Id) changeCount
                FROM User_History__c 
                WHERE User__c = :userId AND Date__c >= :cutoffDate
                GROUP BY Changed_Field__c
                ORDER BY COUNT(Id) DESC
                LIMIT 50
            ];
            
            // Changes by user who made them
            List<AggregateResult> changerStats = [
                SELECT Changed_By__r.Name changerName, COUNT(Id) changeCount
                FROM User_History__c 
                WHERE User__c = :userId AND Date__c >= :cutoffDate
                GROUP BY Changed_By__r.Name
                ORDER BY COUNT(Id) DESC
                LIMIT 50
            ];
            
            summary.put('totalChanges', totalChanges);
            summary.put('fieldChanges', fieldChanges);
            summary.put('changerStats', changerStats);
            summary.put('daysPeriod', days);
            
        // } catch (Exception e) {
        //     System.debug('Error getting summary: ' + e.getMessage());
        //     summary.put('error', e.getMessage());
        // }
        
        return summary;
    }
}