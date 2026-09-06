"""
Generates default_bus_layout.tres with the requested hierarchy:
Master (Limiter)
  ├── Music
  └── SFX
      ├── Weapons (Compressor / punchy transient, ducks SFX)
      ├── Zombies (Reverb wet 0.12, room 0.2)
      ├── Foley
      └── Pickups_UI (High-end clarity EQ)
"""

BUS_LAYOUT_CONTENT = """[gd_resource type="AudioBusLayout" load_steps=5 format=3 uid="uid://c6audiobuslayout01"]

[sub_resource type="AudioEffectLimiter" id="AudioEffectLimiter_master"]
resource_name = "Limiter"
ceiling_db = -0.5
threshold_db = -2.0

[sub_resource type="AudioEffectCompressor" id="AudioEffectCompressor_weapons"]
resource_name = "WeaponsCompressor"
threshold = -2.5
ratio = 4.0
gain = 1.2
attack_us = 20.0
release_ms = 180.0

[sub_resource type="AudioEffectReverb" id="AudioEffectReverb_zombies"]
resource_name = "ZombiesReverb"
room_size = 0.2
damping = 0.5
spread = 0.7
hipass = 0.15
dry = 0.88
wet = 0.12

[sub_resource type="AudioEffectEQ6" id="AudioEffectEQ6_pickups"]
resource_name = "PickupsEQ"
band_db/32_hz = -3.0
band_db/100_hz = -1.5
band_db/320_hz = 0.0
band_db/1000_hz = 1.5
band_db/3200_hz = 3.0
band_db/10000_hz = 3.5

[resource]
bus/0/name = &"Master"
bus/0/solo = false
bus/0/mute = false
bus/0/bypass_fx = false
bus/0/volume_db = 0.0
bus/0/send = &""
bus/0/effect/0/effect = SubResource("AudioEffectLimiter_master")
bus/0/effect/0/enabled = true

bus/1/name = &"Music"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = -3.0
bus/1/send = &"Master"

bus/2/name = &"SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"

bus/3/name = &"Weapons"
bus/3/solo = false
bus/3/mute = false
bus/3/bypass_fx = false
bus/3/volume_db = 0.0
bus/3/send = &"SFX"
bus/3/effect/0/effect = SubResource("AudioEffectCompressor_weapons")
bus/3/effect/0/enabled = true

bus/4/name = &"Zombies"
bus/4/solo = false
bus/4/mute = false
bus/4/bypass_fx = false
bus/4/volume_db = 0.0
bus/4/send = &"SFX"
bus/4/effect/0/effect = SubResource("AudioEffectReverb_zombies")
bus/4/effect/0/enabled = true

bus/5/name = &"Foley"
bus/5/solo = false
bus/5/mute = false
bus/5/bypass_fx = false
bus/5/volume_db = -1.0
bus/5/send = &"SFX"

bus/6/name = &"Pickups_UI"
bus/6/solo = false
bus/6/mute = false
bus/6/bypass_fx = false
bus/6/volume_db = 0.0
bus/6/send = &"SFX"
bus/6/effect/0/effect = SubResource("AudioEffectEQ6_pickups")
bus/6/effect/0/enabled = true
"""

with open("C:/Users/beepl/dev/game/default_bus_layout.tres", "w", encoding="utf-8") as f:
    f.write(BUS_LAYOUT_CONTENT.strip() + "\n")

print("Created default_bus_layout.tres successfully!")
