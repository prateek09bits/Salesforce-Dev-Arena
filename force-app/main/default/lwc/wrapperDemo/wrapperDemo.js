import { LightningElement, api } from 'lwc';

export default class DepartmentDetails extends LightningElement {

    @api value;

    get department() {
        return this.value;
    }

    get employee() {
        return this.value?.employee;
    }
}