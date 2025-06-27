import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchHistoryForLWC from '@salesforce/apex/UserHistorySearchController.searchHistoryForLWC';
import getActiveUsers from '@salesforce/apex/UserHistorySearchController.getActiveUsers';
import getTrackedFields from '@salesforce/apex/UserHistorySearchController.getTrackedFields';

export default class UserHistorySearch extends LightningElement {
    @track searchResults = [];
    @track userOptions = [];
    @track fieldOptions = [];
    @track isSearching = false;
    @track errorMessage = '';
    
    // Filter values
    @track selectedTargetUser = '';
    @track selectedChangedByUser = '';
    @track selectedField = '';
    @track startDate = '';
    @track endDate = '';
    @track recordLimit = 100;
    
    // Table configuration
    @track sortedBy = 'dateChanged';
    @track sortDirection = 'asc';
    
    // Data table columns
    columns = [
        {
            label: 'User',
            fieldName: 'userName',
            type: 'text',
            sortable: true
        },
        {
            label: 'Field Changed',
            fieldName: 'changedField',
            type: 'text',
            sortable: true
        },
        {
            label: 'Old Value',
            fieldName: 'oldValue',
            type: 'text',
            wrapText: true
        },
        {
            label: 'New Value',
            fieldName: 'newValue',
            type: 'text',
            wrapText: true
        },
        {
            label: 'Changed By',
            fieldName: 'changedByName',
            type: 'text',
            sortable: true
        },
        {
            label: 'Date Changed',
            fieldName: 'dateChanged',
            type: 'date',
            sortable: true
        },
        {
            label: 'Time Changed',
            fieldName: 'timeChanged',
            type: 'text'
        }
    ];
    
    // Wire methods to load dropdown options
    @wire(getActiveUsers)
    wiredUsers({ error, data }) {
        if (data) {
            this.userOptions = [
                { label: '-- All Users --', value: '' },
                ...data
            ];
        } else if (error) {
            this.showError('Error loading users: ' + error.body.message);
        }
    }
    
    @wire(getTrackedFields)
    wiredFields({ error, data }) {
        if (data) {
            this.fieldOptions = [
                { label: '-- All Fields --', value: '' },
                ...data
            ];
        } else if (error) {
            this.showError('Error loading fields: ' + error.body.message);
        }
    }
    
    // Event handlers for filter changes
    handleTargetUserChange(event) {
        this.selectedTargetUser = event.detail.value;
    }
    
    handleChangedByUserChange(event) {
        this.selectedChangedByUser = event.detail.value;
    }
    
    handleFieldChange(event) {
        this.selectedField = event.detail.value;
    }
    
    handleStartDateChange(event) {
        this.startDate = event.detail.value;
    }
    
    handleEndDateChange(event) {
        this.endDate = event.detail.value;
    }
    
    handleLimitChange(event) {
        this.recordLimit = event.detail.value;
    }
    
    // Search functionality
    searchHistory() {
        this.isSearching = true;
        this.errorMessage = '';
        this.hasSearched = true; // Mark that a search has been performed
        
        // Validate date range
        if (this.startDate && this.endDate && this.startDate > this.endDate) {
            this.showError('Start date cannot be after end date');
            this.isSearching = false;
            return;
        }
        
        searchHistoryForLWC({
            targetUserId: this.selectedTargetUser,
            changedByUserId: this.selectedChangedByUser,
            fieldName: this.selectedField,
            startDateStr: this.startDate,
            endDateStr: this.endDate,
            limitRecords: this.recordLimit
        })
        .then(result => {
            console.log('Raw result from Apex:', result);
            
            // Transform the data to match what the datatable expects
            this.searchResults = result.map(record => {
                const transformedRecord = {
                    recordId: record.recordId,
                    userId: record.userId,
                    userName: record.userName || 'Unknown User',
                    changedField: record.changedField || 'Unknown Field',
                    oldValue: record.oldValue || '',
                    newValue: record.newValue || '',
                    changedBy: record.changedBy,
                    changedByName: record.changedByName || 'Unknown User',
                    dateChanged: record.dateChanged,
                    timeChanged: this.formatTime(record.timeChanged)
                };
                console.log('Transformed record:', transformedRecord);
                return transformedRecord;
            });
            
            console.log('Final searchResults:', this.searchResults);
            this.isSearching = false;
            
            if (this.searchResults.length === 0) {
                this.showToast('No Results', 'No history records found matching your criteria.', 'info');
            } else {
                this.showToast('Success', `Found ${this.searchResults.length} history records.`, 'success');
            }
        })
        .catch(error => {
            this.isSearching = false;
            console.error('Search error:', error);
            let errorMessage = 'Unknown error occurred';
            if (error.body && error.body.message) {
                errorMessage = error.body.message;
            } else if (error.message) {
                errorMessage = error.message;
            }
            this.showError('Search failed: ' + errorMessage);
        });
    }
    
    // Helper method to format time
    formatTime(timeValue) {
        if (!timeValue) return '';
        
        // If it's already a string, return as is
        if (typeof timeValue === 'string') {
            return timeValue;
        }
        
        // If it's a time object, format it
        try {
            // Handle different time formats
            if (timeValue.toString) {
                return timeValue.toString();
            }
            return String(timeValue);
        } catch (e) {
            console.error('Error formatting time:', e);
            return '';
        }
    }
    
    // Clear all filters
    clearFilters() {
        this.selectedTargetUser = '';
        this.selectedChangedByUser = '';
        this.selectedField = '';
        this.startDate = '';
        this.endDate = '';
        this.recordLimit = 100;
        this.searchResults = [];
        this.errorMessage = '';
        this.hasSearched = false; // Reset search state
    }
    
    // Table sorting
    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        
        // Simple client-side sorting
        this.searchResults = [...this.searchResults].sort((a, b) => {
            let aVal = a[this.sortedBy] || '';
            let bVal = b[this.sortedBy] || '';
            
            // Handle date sorting
            if (this.sortedBy === 'dateChanged') {
                aVal = new Date(aVal);
                bVal = new Date(bVal);
            }
            
            if (this.sortDirection === 'asc') {
                return aVal > bVal ? 1 : -1;
            } else {
                return aVal < bVal ? 1 : -1;
            }
        });
    }
    
    // Export functionality
    exportResults() {
        if (this.searchResults.length === 0) {
            this.showToast('No Data', 'No results to export.', 'warning');
            return;
        }
        
        // Create CSV content
        const headers = ['User', 'Field Changed', 'Old Value', 'New Value', 'Changed By', 'Date Changed', 'Time Changed'];
        let csvContent = headers.join(',') + '\n';
        
        this.searchResults.forEach(row => {
            const csvRow = [
                this.escapeCsvValue(row.userName),
                this.escapeCsvValue(row.changedField),
                this.escapeCsvValue(row.oldValue),
                this.escapeCsvValue(row.newValue),
                this.escapeCsvValue(row.changedByName),
                row.dateChanged,
                row.timeChanged
            ];
            csvContent += csvRow.join(',') + '\n';
        });
        
        // Download CSV
        const element = document.createElement('a');
        element.setAttribute('href', 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent));
        element.setAttribute('download', 'user_history_' + new Date().toISOString().split('T')[0] + '.csv');
        element.style.display = 'none';
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
        
        this.showToast('Success', 'Results exported successfully.', 'success');
    }
    
    // Helper methods
    escapeCsvValue(value) {
        if (!value) return '';
        const stringValue = String(value);
        if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
            return '"' + stringValue.replace(/"/g, '""') + '"';
        }
        return stringValue;
    }
    
    showError(message) {
        this.errorMessage = message;
        this.showToast('Error', message, 'error');
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
    
    // Track if search has been performed
    @track hasSearched = false;
    
    // Getters for template conditionals
    get showResults() {
        return this.searchResults.length > 0;
    }
    
    get showNoResults() {
        return this.hasSearched && !this.isSearching && this.searchResults.length === 0 && this.errorMessage === '';
    }
    
    get isExportDisabled() {
        return this.searchResults.length === 0;
    }
}