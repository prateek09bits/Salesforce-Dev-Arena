public with sharing class WrapperDemoController {

    /*
     * ================================
     * Inner Employee Wrapper
     * ================================
     */
    public class EmployeeWrapper {

        @InvocableVariable(
            label='Employee Name'
            description='Name of the employee'
        )
        public String employeeName;

        @InvocableVariable(
            label='Designation'
            description='Employee designation'
        )
        public String designation;

        @InvocableVariable(
            label='Salary'
            description='Employee salary'
        )
        public Decimal salary;
    }


    /*
     * ================================
     * Outer Department Wrapper
     * ================================
     */
    public class DepartmentWrapper {

        @InvocableVariable(
            label='Department Name'
            description='Name of the department'
        )
        public String departmentName;

        @InvocableVariable(
            label='Manager Name'
            description='Name of the department manager'
        )
        public String managerName;

        @InvocableVariable(
            label='Employee'
            description='Employee details'
        )
        public EmployeeWrapper employee;
    }


    /*
     * ================================
     * Invocable Request
     * ================================
     */
    public class Request {

        @InvocableVariable(
            label='Department'
            description='Department to retrieve'
            required=true
        )
        public String departmentName;
    }


    /*
     * ================================
     * Invocable Action
     * ================================
     */
    @InvocableMethod(
        label='Get Department Details'
        description='Returns department information with nested employee details'
    )
    public static List<DepartmentWrapper> getDepartmentDetails(
        List<Request> requests
    ) {

        List<DepartmentWrapper> results =
            new List<DepartmentWrapper>();

        for (Request request : requests) {

            /*
             * Inner wrapper
             */
            EmployeeWrapper employee =
                new EmployeeWrapper();

            employee.employeeName = 'John Smith';
            employee.designation = 'Salesforce Developer';
            employee.salary = 85000;


            /*
             * Outer wrapper
             */
            DepartmentWrapper department =
                new DepartmentWrapper();

            department.departmentName =
                request.departmentName;

            department.managerName =
                'David Manager';

            department.employee =
                employee;


            results.add(department);
        }

        return results;
    }
}