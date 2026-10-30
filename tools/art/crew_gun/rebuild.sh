# every approved / pending clip: src gun shots out aim [drop]
set -e
f() { rm -rf $4; python3 fx.py "$@" >/dev/null; }
SNAP=1 f medic/shoot_A pistol 1,5 medic/fx_A level
SNAP=1 f medic/shoot_B3 smg 2,3,4 medic/fx_B level 8
for k in A B; do for a in up down; do SNAP=1 f medic/rc_${k}_$a $([ $k = A ] && echo "pistol 1,5" || echo "smg 1,3,5") medic/fx_${k}_$a $a; done; done
f aviator_pilot/shoot_A2 flare 2 aviator_pilot/fx_A level 1
f aviator_pilot/shoot_B2 pistol 1,5 aviator_pilot/fx_B level 3
f biker/shoot_A1 sawnoff 2 biker/fx_A level
f biker/shoot_B2_1 revolver 1,5 biker/fx_B1 level
f biker/shoot_B2_3 revolver 1,5 biker/fx_B2 level
f bus_mechanic/shoot_A shotgun 2 bus_mechanic/fx_A level
f bus_mechanic/shoot_B nailgun 1,3,5 bus_mechanic/fx_B level
HOLD=construction_worker/hold_A.png f construction_worker/shoot_A rifle 1,3,5 construction_worker/fx_A level
HOLD=construction_worker/hold_B.png f construction_worker/shoot_B1 sawnoff 2 construction_worker/fx_B1 level
HOLD=construction_worker/hold_B.png f construction_worker/shoot_B3 sawnoff 2 construction_worker/fx_B3 level
HOLD=firefighter/hold_A.png f firefighter/shoot_A rifle 1,5 firefighter/fx_A level
f firefighter/shoot_B flamer 1,4 firefighter/fx_B level
python3 lockfeet.py fortune_teller/shoot_A3 fortune_teller/shoot_A3L40 40
HOLD=fortune_teller/hold_A.png f fortune_teller/shoot_A3L40 revolver 1,4 fortune_teller/fx_A level
HOLD=fortune_teller/hold_B.png f fortune_teller/shoot_B2 flintlock 1 fortune_teller/fx_B level
HOLD=gunslinger/hold_A.png f gunslinger/shoot_A revolver 1,3,5 gunslinger/fx_A level
HOLD=gunslinger/hold_B.png f gunslinger/shoot_B revolver 1,4b gunslinger/fx_B level; python3 erase.py gunslinger/fx_B 0 0 21 22
HOLD=hunter/hold_A.png f hunter/shoot_A boltrifle_smoke 1 hunter/fx_A level
HOLD=hunter/hold_B.png f hunter/shoot_B sawnoff_smoke 2 hunter/fx_B level; python3 erase.py hunter/fx_B 0 0 17 30
f lounge_singer/shoot_A revolver 1,4 lounge_singer/fx_A level
BORE2=1 f lounge_singer/shoot_B smg 2,3,4 lounge_singer/fx_B level
f monk/shoot_A airpuff 2 monk/fx_A level
rm -rf monk/shoot_B; python3 recoil.py monk/hold_B.png monk/shoot_B 02100210; f monk/shoot_B airpuff 1,5 monk/fx_B level
rm -rf motorbike_courier/shoot_A; BODY=1 python3 recoil.py motorbike_courier/hold_A.png motorbike_courier/shoot_A 012121210; f motorbike_courier/shoot_A smg 2,4,6 motorbike_courier/fx_A level
f motorbike_courier/shoot_B pistol 1,5 motorbike_courier/fx_B level
# courier A with PixelLab burst (ponytail swing), legs pinned: takes 2 and 3
for s in 2 3; do python3 lockfeet.py motorbike_courier/shoot_A$s motorbike_courier/shoot_A${s}L 37; HOLD=motorbike_courier/hold_A.png f motorbike_courier/shoot_A${s}L smg 2,3,4 motorbike_courier/fx_A${s}L level; done
for s in 2 3; do python3 lockfeet.py motorbike_courier/shoot_B$s motorbike_courier/shoot_B${s}L 37; HOLD=motorbike_courier/hold_B.png f motorbike_courier/shoot_B${s}L pistol 1,5 motorbike_courier/fx_B${s}L level; done
for s in 2 3; do rm -rf motorbike_courier/fx_B${s}H; cp -r motorbike_courier/fx_B${s}L motorbike_courier/fx_B${s}H; python3 hairfx.py motorbike_courier/fx_B${s}H 54,41,38; done
for o in A B; do rm -rf office_worker/shoot_${o}L; python3 lockfeet.py office_worker/shoot_$o office_worker/shoot_${o}L 37; python3 declutter.py office_worker/shoot_${o}L office_worker/hold_$o.png 46:72 30 >/dev/null; done
HOLD=office_worker/hold_A.png f office_worker/shoot_AL smg 1,2,3,4 office_worker/fx_A level
rm -rf office_worker/shoot_BR; BODY=1 python3 recoil.py office_worker/hold_B.png office_worker/shoot_BR 012100121; f office_worker/shoot_BR nailgun 2,7 office_worker/fx_B level
