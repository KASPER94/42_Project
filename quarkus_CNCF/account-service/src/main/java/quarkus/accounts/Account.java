package quarkus.accounts;

import java.math.BigDecimal;

public class Account {
    public  Long        accountNumber;
    public  Long        customerNumber;
    public  String      customerName;
    public  BigDecimal  accountBalance;
    public  AccountStatus   accountStatus = AccountStatus.OPEN;
    
    public Account() {}

    public Account(Long accountNumber, Long customerNumber,
        String customerName, BigDecimal accountBalance) {
            this.accountNumber =accountNumber;
            this.customerNumber = customerNumber;
            this.customerName = customerName;
            this.accountBalance = accountBalance;
        }

    public  void    markOverdrawn() {
        accountStatus = AccountStatus.OVERDRAWN;
    }

    public  void    removeOverdrawn() {
        accountStatus = AccountStatus.OPEN;
    }

    public  void closeAccount() {
        accountStatus = AccountStatus.CLOSED;
        accountBalance = BigDecimal.valueOf(0);
    }

    public  void    withdrawFunds(BigDecimal amount) {
        accountBalance = accountBalance.subtract(amount);
    }

    public  void    addFunds(BigDecimal amount) {
        accountBalance = accountBalance.add(amount);
    }

    public BigDecimal   getAccountBalance() {
        return accountBalance;
    }

    public Long   getAccountNumber() {
        return accountNumber;
    }

    public AccountStatus    getAccountStatus() {
        return accountStatus;
    }

    public  String          getCustomerName() {
        return  customerName;
    }
}
