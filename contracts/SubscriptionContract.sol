// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SubscriptionContract {
  address public serviceAddress = msg.sender;
  bool public halted = false;

  struct Subscription {
    bytes id; // bytes concatenation of addresses of owner, subscriber, and token
    bytes uuid;
    address ownerAddress;
    address subscriberAddress;
    address tokenAddress; // subscription denominated token
    uint lastSettlementTime;
    uint value; // subscription value
    uint interval; // subscription interval in seconds

    // non-state variables
    uint ownerSubscriptionIndex;
    uint subscriberSubscriptionIndex;
    uint index;
    bool exists;
  }

  struct Owner {
    bytes[] subscriptionIDs;
    uint index;
    bool exists;
  }

  struct Subscriber {
    bytes[] subscriptionIDs;
    uint index;
    bool exists;
  }

  event SubscriptionAdded(
    bytes id,
    bytes uuid,
    address ownerAddress,
    address subscriberAddress,
    address tokenAddress,
    uint value,
    uint interval
  );

  event SettlementSuccess(
    bytes id,
    bytes uuid,
    address ownerAddress,
    address subscriberAddress,
    address tokenAddress,
    uint value
  );

  event SettlementFailure(
    bytes id,
    bytes uuid,
    address ownerAddress,
    address subscriberAddress,
    address tokenAddress,
    uint value
  );

  event SubscriptionRemoved(
    bytes id,
    bytes uuid,
    address ownerAddress,
    address subscriberAddress,
    address tokenAddress
  );

  mapping (address => Owner) public owners;
  mapping (address => Subscriber) public subscribers;
  mapping (bytes => Subscription) public subscriptions;

  address[] public ownerIndices;
  address[] public subscriberIndices;
  bytes[] public subscriptionIndices;

  modifier restricted() {
    require(
      msg.sender == serviceAddress,
      "This function is restricted to the contract's service address"
    );
    _;
  }

  modifier notHalt() {
    require(
      !halted,
      "This function is not permitted when contract is halted"
    );
    _;
  }

  function halt() public restricted {
    halted = true;
  }

  function unhalt() public restricted {
    halted = false;
  }

  function makeID(
    bytes calldata uuid,
    address subscriberAddress
  ) pure external returns (bytes memory) {
    return abi.encodePacked(uuid, subscriberAddress);
  }

  function addSubscription(
    address ownerAddress,
    address tokenAddress,
    uint value,
    uint interval,
    bytes calldata uuid
  ) public notHalt returns (Subscription memory) {
    address subscriberAddress = msg.sender;
    bytes memory subscriptionID = this.makeID(uuid, subscriberAddress);

    // Assert that subscription does not exist
    require(subscriptions[subscriptionID].exists != true);
    require(value > 0);
    require(interval > 0);
    require(uuid.length > 1);

    IERC20 erc20 = IERC20(tokenAddress);
    require(erc20.transferFrom(subscriberAddress, ownerAddress, value));

    if (owners[ownerAddress].exists == true) {
      owners[ownerAddress].subscriptionIDs.push(subscriptionID);
    } else {
      ownerIndices.push(ownerAddress);
      bytes[] memory emptySubIDs;
      owners[ownerAddress] = Owner({
        exists: true,
        subscriptionIDs: emptySubIDs,
        index: ownerIndices.length - 1
      });
      owners[ownerAddress].subscriptionIDs.push(subscriptionID);
    }

    if (subscribers[subscriberAddress].exists == true) {
      subscribers[subscriberAddress].subscriptionIDs.push(subscriptionID);
    } else {
      subscriberIndices.push(subscriberAddress);
      bytes[] memory emptySubIDs;
      subscribers[subscriberAddress] = Subscriber({
        exists: true,
        subscriptionIDs: emptySubIDs,
        index: subscriberIndices.length - 1
      });
      subscribers[subscriberAddress].subscriptionIDs.push(subscriptionID);
    }

    subscriptionIndices.push(subscriptionID);

    Subscription memory subscription = Subscription({
      id: subscriptionID,
      uuid: uuid,
      ownerAddress: ownerAddress,
      subscriberAddress: subscriberAddress,
      tokenAddress: tokenAddress,
      lastSettlementTime: block.timestamp,
      value: value,
      interval: interval,
      index: subscriptionIndices.length - 1,
      ownerSubscriptionIndex: owners[ownerAddress].subscriptionIDs.length - 1,
      subscriberSubscriptionIndex: subscribers[subscriberAddress].subscriptionIDs.length - 1,
      exists: true
    });

    subscriptions[subscriptionID] = subscription;

    emit SubscriptionAdded(
      subscriptionID,
      uuid,
      ownerAddress,
      subscriberAddress,
      tokenAddress,
      value,
      interval
    );
    return subscription;
  }

  function removeSubscription(bytes calldata subscriptionID) public returns (bool) {
    address subscriberAddress = msg.sender;

    require(subscriptions[subscriptionID].exists);

    Subscription memory deletedSubscription = subscriptions[subscriptionID];

    require(subscriberAddress == deletedSubscription.subscriberAddress);

    if (deletedSubscription.index != subscriptionIndices.length - 1) {
      bytes memory lastSubscriptionID = subscriptionIndices[subscriberIndices.length - 1];
      subscriptionIndices[deletedSubscription.index] = lastSubscriptionID;
      subscriptions[lastSubscriptionID].index = deletedSubscription.index;
    }

    Owner storage owner = owners[deletedSubscription.ownerAddress];

    if (deletedSubscription.ownerSubscriptionIndex != owner.subscriptionIDs.length - 1) {
      bytes memory lastOwnerSubID = owner.subscriptionIDs[owner.subscriptionIDs.length - 1];
      owner.subscriptionIDs[deletedSubscription.ownerSubscriptionIndex] = lastOwnerSubID;
      subscriptions[lastOwnerSubID].ownerSubscriptionIndex = deletedSubscription.ownerSubscriptionIndex;
    }

    Subscriber storage subscriber = subscribers[deletedSubscription.subscriberAddress];

    if (deletedSubscription.subscriberSubscriptionIndex != subscriber.subscriptionIDs.length - 1) {
      bytes memory lastSubscriberSubID = subscriber.subscriptionIDs[subscriber.subscriptionIDs.length - 1];
      subscriber.subscriptionIDs[deletedSubscription.subscriberSubscriptionIndex] = lastSubscriberSubID;
      subscriptions[lastSubscriberSubID].subscriberSubscriptionIndex = deletedSubscription.subscriberSubscriptionIndex;
    }

    delete subscriptions[subscriptionID];
    subscriptionIndices.pop();
    owner.subscriptionIDs.pop();
    subscriber.subscriptionIDs.pop();

    emit SubscriptionRemoved(
      subscriptionID,
      deletedSubscription.uuid,
      deletedSubscription.ownerAddress,
      deletedSubscription.subscriberAddress,
      deletedSubscription.tokenAddress
    );

    return true;
  }

  function internalRemoveSubscription(bytes calldata subscriptionID) internal returns (bool) {
    require(subscriptions[subscriptionID].exists);

    Subscription memory deletedSubscription = subscriptions[subscriptionID];

    if (deletedSubscription.index != subscriptionIndices.length - 1) {
      bytes memory lastSubscriptionID = subscriptionIndices[subscriberIndices.length - 1];
      subscriptionIndices[deletedSubscription.index] = lastSubscriptionID;
      subscriptions[lastSubscriptionID].index = deletedSubscription.index;
    }

    Owner storage owner = owners[deletedSubscription.ownerAddress];

    if (deletedSubscription.ownerSubscriptionIndex != owner.subscriptionIDs.length - 1) {
      bytes memory lastOwnerSubID = owner.subscriptionIDs[owner.subscriptionIDs.length - 1];
      owner.subscriptionIDs[deletedSubscription.ownerSubscriptionIndex] = lastOwnerSubID;
      subscriptions[lastOwnerSubID].ownerSubscriptionIndex = deletedSubscription.ownerSubscriptionIndex;
    }

    Subscriber storage subscriber = subscribers[deletedSubscription.subscriberAddress];

    if (deletedSubscription.subscriberSubscriptionIndex != subscriber.subscriptionIDs.length - 1) {
      bytes memory lastSubscriberSubID = subscriber.subscriptionIDs[subscriber.subscriptionIDs.length - 1];
      subscriber.subscriptionIDs[deletedSubscription.subscriberSubscriptionIndex] = lastSubscriberSubID;
      subscriptions[lastSubscriberSubID].subscriberSubscriptionIndex = deletedSubscription.subscriberSubscriptionIndex;
    }

    delete subscriptions[subscriptionID];
    subscriptionIndices.pop();
    owner.subscriptionIDs.pop();
    subscriber.subscriptionIDs.pop();

    emit SubscriptionRemoved(
      subscriptionID,
      deletedSubscription.uuid,
      deletedSubscription.ownerAddress,
      deletedSubscription.subscriberAddress,
      deletedSubscription.tokenAddress
    );

    return true;
  }

  function settleSubscription(bytes calldata subscriptionID) public returns (bool) {
    Subscription storage subscription = subscriptions[subscriptionID];

    require(subscription.exists);

    uint gap = block.timestamp - subscription.lastSettlementTime;

    uint allowedPayments = gap / subscription.interval;

    if (allowedPayments < 1) {
      return false;
    }

    bool result = false;

    try IERC20(subscription.tokenAddress).transferFrom(subscription.subscriberAddress, subscription.ownerAddress,allowedPayments * subscription.value) returns (bool b) {
      result = b;
    } catch {
      result = false;
    }


    if (result) {
      subscription.lastSettlementTime = subscription.lastSettlementTime + (allowedPayments * subscription.interval);
      emit SettlementSuccess(
        subscriptionID,
        subscription.uuid,
        subscription.ownerAddress,
        subscription.subscriberAddress,
        subscription.tokenAddress,
        allowedPayments * subscription.value
      );
      return true;
    } else {
      internalRemoveSubscription(subscriptionID);
      emit SettlementFailure(
        subscriptionID,
        subscription.uuid,
        subscription.ownerAddress,
        subscription.subscriberAddress,
        subscription.tokenAddress,
        allowedPayments * subscription.value
      );
      return false;
    }
  }

  function settleOwnerSubscriptions(address ownerAddress) public returns (bool) {
    Owner memory owner = owners[ownerAddress];

    require(owner.exists);

    for (uint i = 0; i < owner.subscriptionIDs.length; i++) {
      this.settleSubscription(owner.subscriptionIDs[i]);
    }

    return true;
  }

  function getClaimableAmount(address ownerAddress, address tokenAddress) public view returns (uint) {
    Owner memory owner = owners[ownerAddress];

    require(owner.exists);

    uint answer = 0;

    for (uint i = 0; i < owner.subscriptionIDs.length; i++) {
      Subscription memory subscription = subscriptions[owner.subscriptionIDs[i]];
      if (subscription.tokenAddress == tokenAddress) {
        answer = answer + this.getAmountOwed(owner.subscriptionIDs[i]);
      }
    }

    return answer;
  }

  function getAmountOwed(bytes calldata subscriptionID) public view returns (uint) {
    Subscription memory subscription = subscriptions[subscriptionID];

    require(subscription.exists);

    return ((block.timestamp - subscription.lastSettlementTime) / subscription.interval) * subscription.value;
  }

  function getIDsByOwner(address ownerAddress) public view returns(bytes[] memory) {
    Owner memory owner = owners[ownerAddress];
    require(owner.exists);
    return owner.subscriptionIDs;
  }

  function getIDsBySubscriber(address subscriberAddress) public view returns(bytes[] memory) {
    Subscriber memory subscriber = subscribers[subscriberAddress];
    require(subscriber.exists);
    return subscriber.subscriptionIDs;
  }
}
