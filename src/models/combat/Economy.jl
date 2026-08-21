function shop_items(match::CombatMatch, participant::Participant)
    map = target_board(match, participant).map
    return [ShopItemState(
        weapon,
        weapon_price(weapon),
        weapon_quota(map, weapon) - match.purchased[participant][weapon],
        match.inventories[participant][weapon],
    ) for weapon in weapons()]
end

function buy_weapon!(match::CombatMatch, participant::Participant, weapon::WeaponType)
    match.shop_available[participant] && match.turn == participant && isnothing(match.winner) ||
        return PurchaseResult(false, weapon, SHOP_CLOSED)
    price = weapon_price(weapon)
    match.coins[participant] >= price ||
        return PurchaseResult(false, weapon, INSUFFICIENT_FUNDS)
    map = target_board(match, participant).map
    match.purchased[participant][weapon] < weapon_quota(map, weapon) ||
        return PurchaseResult(false, weapon, QUOTA_EXHAUSTED)
    match.coins[participant] -= price
    match.purchased[participant][weapon] += 1
    match.inventories[participant][weapon] += 1
    return PurchaseResult(true, weapon, nothing)
end
