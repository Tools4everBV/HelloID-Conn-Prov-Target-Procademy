
# HelloID-Conn-Prov-Target-Procademy

| :warning: Warning |
|:---------------------------|
| Note that this connector is "a work in progress" and therefore not ready to use in your production environment. |

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="https://uploads-ssl.webflow.com/5df902230ef2cc43108c2ffb/5df904140ef2cc580a8c40ef_procademy-logo-web.svg">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Procademy](#helloid-conn-prov-target-procademy)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
      - [Account verification](#account-verification)
      - [Update account](#update-account)
      - [`$aRef` not being used](#aref-not-being-used)
      - [Entitlements](#entitlements)
      - [channel\_id](#channel_id)
      - [Correlation based on `procademy_user_id`](#correlation-based-on-procademy_user_id)
      - [Error handling](#error-handling)
  - [Setup the connector](#setup-the-connector)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Procademy_ is a _target_ connector. Procademy provides a set of REST API's that allow you to programmatically interact with its data. The HelloID connector uses the API endpoints listed in the table below.

| Endpoint     | Description |
| ------------ | ----------- |
| [api/v2/users/store/bulk | This endpoint is used to create one (or multiple) accounts. |
| api/v2/users/deactivate | This endpoint is used to deactivate one (or multiple) accounts |

The following lifecycle events are available:

| Event  | Description | Notes |
|---	 |---	|---	|
| create.ps1 | Create (or update) and correlate an account | Verification to check if the account exists is not available. See [account verification](#Account-verification) |
| update.ps1 | Update the Account | Update (or create) and correlate an account | Verification to check if the account exists is not available. See [account verification](#Account-verification)  |
| disable.ps1 | Disable the Account | Deactivates the account  |

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting | Description| Mandatory |
| ------------ | -----------| ----------- |
| AuthenticationKey | The AuthenticationKey to connect to the Procademy API | Yes |
| BaseUrl | The URL to the Procademy API | Yes |

### Prerequisites

None.

### Remarks

Procademy is a somewhat different API in the sense that we cannot retrieve users from the Procademy API and the verification if the account must be created or updated is being done within Procademy itself. This has some implications on the way the connector works.

#### Account verification

 An API call to retrieve a user account is not available. When a user account is created, (send to the 'bulk' endpoint) Procademy uses the `external_id` to verify if the user account already exists. If not, the account will be created or otherwise updated.

#### Update account

Normally we offer the possibility to update the account if it already exists. However, since Procademy verifies the account existence internally, we don't know if the account will be created or updated.

As a result, the option to update the account from the configuration settings, is not available and both `create.ps1` and `update.ps1` have a somewhat different look and feel.

#### `$aRef` not being used

Because we cannot retrieve the account from Procademy, the `$aRef` is not being used in this connector.

#### Entitlements

Entitlements (known as 'groupId's) are a part of the `account` object in both the create and update lifecycle events. At this point it is unclear how many groupId's there are and if we can retrieve them from Procademy.

#### channel_id

A user can be created with a property called `channel_id`. At this point its unclear if this is being used. However, users created with this property can only be deactivated using the same channel_id.

#### Correlation based on `procademy_user_id`

The account correlation currently uses the 'procademy_user_id'. The assumption is that this id is also used to deactivate the account.

#### Error handling

The connector is coded without access to a test environment. Therefore, error handling has not been implemented apart from the default error handling behavior. This will need to be adjusted accordingly during implementation.

## Setup the connector

No special setup actions are required.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
