Feature: Pages should be secured
  I want to only see pages that I am authenticated for

  Scenario: Open page
    Given I am at http://localhost:5984/zanzibar/_design/zanzibar/index.html
    Then I should see "Username"

  Scenario: Successful login
    Given I am at http://localhost:5984/zanzibar/_design/zanzibar/index.html#reports
    Then I should not see "Cases"
    When I fill username with reports
    And I fill password with stroper
    And I press Login
    #Then I am at http://localhost:5984/zanzibar/_design/zanzibar/index.html#reports
    Then I should not see "Username"
    And I should see "Cases" 
