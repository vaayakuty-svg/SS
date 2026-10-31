extends Node
## First working story mission: help Marshal Reed stop Coyote Ridge bandits.
signal mission_message(message: String)
var stage := 0 # 0 available, 1 hunting, 2 return, 3 complete.
var bandits_defeated := 0
var total_bandits := 3
var visited_camp := false

func sheriff_interaction() -> Dictionary:
    if stage == 0:
        stage = 1
        if bandits_defeated >= total_bandits:
            stage = 2
        mission_message.emit("MISSION STARTED: Coyote Ridge Cleanup")
        return {"message": "Marshal Reed: Three raiders are hiding east of town. Bring peace to the ridge!", "reward": 0}
    if stage == 1:
        return {"message": "Marshal Reed: Head east to Coyote Ridge. Bring the raiders down.", "reward": 0}
    if stage == 2:
        stage = 3
        mission_message.emit("MISSION COMPLETE  •  $75 + 10 Honor")
        return {"message": "Marshal Reed: Fine work. These folks can sleep again. $75 reward!", "reward": 75}
    return {"message": "Marshal Reed: You have my thanks, deputy.", "reward": 0}

func bandit_killed() -> void:
    bandits_defeated = mini(total_bandits, bandits_defeated + 1)
    if stage != 1:
        return
    mission_message.emit("Raiders defeated: %d / %d" % [bandits_defeated, total_bandits])
    if bandits_defeated >= total_bandits:
        stage = 2
        mission_message.emit("All raiders defeated! Return to Marshal Reed.")

func check_camp(player_pos: Vector3, camp_pos: Vector3) -> void:
    if stage == 1 and not visited_camp and player_pos.distance_to(camp_pos) < 23.0:
        visited_camp = true
        mission_message.emit("COYOTE RIDGE DISCOVERED: Clear the raider camp!")

func objective() -> String:
    match stage:
        0:
            return "Meet Marshal Reed outside the sheriff's office"
        1:
            return "Ride east to Coyote Ridge • Defeat raiders (%d/%d)" % [bandits_defeated, total_bandits]
        2:
            return "Return to Marshal Reed to claim your reward"
        _:
            return "Coyote Ridge is safe • Explore the frontier"
