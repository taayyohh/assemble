// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Social Library
/// @notice Library for handling social graph functionality
/// @author taayyohh
library SocialLibrary {
    /// @notice RSVP status for social coordination
    enum RSVPStatus {
        NO_RESPONSE,
        GOING,
        INTERESTED,
        NOT_GOING
    }

    /// @notice Add a friend to social graph
    /// @param isFriend Storage mapping of friend relationships
    /// @param friendLists Storage mapping of friend lists
    /// @param user User adding friend
    /// @param friend Address to add as friend
    function addFriend(
        mapping(address => mapping(address => bool)) storage isFriend,
        mapping(address => address[]) storage friendLists,
        address user,
        address friend
    )
        external
    {
        require(friend != user, "Cannot add self");
        require(friend != address(0), "Invalid address");
        require(!isFriend[user][friend], "Already friends");

        isFriend[user][friend] = true;
        friendLists[user].push(friend);
    }

    /// @notice Remove a friend from social graph
    /// @param isFriend Storage mapping of friend relationships
    /// @param friendLists Storage mapping of friend lists
    /// @param user User removing friend
    /// @param friend Address to remove as friend
    function removeFriend(
        mapping(address => mapping(address => bool)) storage isFriend,
        mapping(address => address[]) storage friendLists,
        address user,
        address friend
    )
        external
    {
        require(isFriend[user][friend], "Not friends");

        isFriend[user][friend] = false;

        // Remove from friend list
        address[] storage friends = friendLists[user];
        for (uint256 i = 0; i < friends.length; i++) {
            if (friends[i] == friend) {
                friends[i] = friends[friends.length - 1];
                friends.pop();
                break;
            }
        }
    }

    /// @notice Update RSVP status for an event
    /// @param rsvps Storage mapping of RSVPs
    /// @param attendeeLists Storage mapping of attendee lists
    /// @param eventId Event identifier
    /// @param user User updating RSVP
    /// @param status New RSVP status
    function updateRSVP(
        mapping(uint256 => mapping(address => RSVPStatus)) storage rsvps,
        mapping(uint256 => address[]) storage attendeeLists,
        uint256 eventId,
        address user,
        RSVPStatus status
    )
        external
    {
        RSVPStatus oldStatus = rsvps[eventId][user];
        rsvps[eventId][user] = status;

        // Update attendee list if status changed to/from GOING
        if (oldStatus != RSVPStatus.GOING && status == RSVPStatus.GOING) {
            attendeeLists[eventId].push(user);
        } else if (oldStatus == RSVPStatus.GOING && status != RSVPStatus.GOING) {
            // Remove from attendee list
            address[] storage attendees = attendeeLists[eventId];
            for (uint256 i = 0; i < attendees.length; i++) {
                if (attendees[i] == user) {
                    attendees[i] = attendees[attendees.length - 1];
                    attendees.pop();
                    break;
                }
            }
        }
    }

    /// @notice Get friends attending an event
    /// @param friendLists Storage mapping of friend lists
    /// @param rsvps Storage mapping of RSVPs
    /// @param eventId Event identifier
    /// @param user User to check friends for
    /// @return friendsGoing Array of friends attending the event
    function getFriendsAttending(
        mapping(address => address[]) storage friendLists,
        mapping(uint256 => mapping(address => RSVPStatus)) storage rsvps,
        uint256 eventId,
        address user
    )
        external
        view
        returns (address[] memory friendsGoing)
    {
        address[] memory friends = friendLists[user];

        // Count friends going first
        uint256 count = 0;
        for (uint256 i = 0; i < friends.length; i++) {
            if (rsvps[eventId][friends[i]] == RSVPStatus.GOING) {
                count++;
            }
        }

        // Build result array
        friendsGoing = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < friends.length; i++) {
            if (rsvps[eventId][friends[i]] == RSVPStatus.GOING) {
                friendsGoing[index] = friends[i];
                index++;
            }
        }
    }
}
