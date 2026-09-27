"""Compile the authored Greymere map definitions. No combat or story data is generated."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game/world"

def rect(grid, x, y, w, h, char):
    for j in range(y, y+h):
        for i in range(x, x+w):
            grid[j][i] = char

def prop(asset, x, y, **kwargs):
    return dict(asset=asset, tile=[x, y], **kwargs)

def npc(name, key, dialogue, x, y, facing=(0, 1)):
    return dict(name=name, sprite_key=key, dialogue=dialogue, tile=[x,y], facing=list(facing))

def entrance(id, x, y, destination, return_spawn, locked=False):
    return dict(building_id=id, tile=[x,y], destination_location=destination,
                destination_scene=f"res://scenes/overworld/{destination}.tscn",
                destination_spawn="approach" if destination == "greymere" else "entrance", return_spawn=return_spawn,
                locked=locked, locked_dialogue_id="locked_door", transition_type="fade", verb="Enter")

def spawn(x,y,facing=(0,1)):
    return dict(tile=[x,y], facing=list(facing))

def compile_world():
    width, height = 46, 34
    grid = [["." for _ in range(width)] for _ in range(height)]
    for x,y,w,h in [(0,0,width,2),(0,height-2,width,2),(0,0,2,height),(width-2,0,2,height)]: rect(grid,x,y,w,h,"#")
    # Irregular central square, southern approach and upper gate staircase.
    for x,y,w,h in [(16,6,3,26),(14,13,7,10),(12,16,11,5),(8,10,18,2),(9,20,16,3),(9,10,2,14),(23,10,2,13)]:
        rect(grid,x,y,w,h,":")
    rect(grid,15,6,5,3,"^")
    # Creek beyond the west lane. The walkable bridge is explicit terrain.
    rect(grid,3,21,3,10,"~")
    rect(grid,3,25,3,2,"=")
    rect(grid,6,25,9,2,":")
    # East lane: Gell's shop and Joey's family home face it from the north;
    # a quieter path turns south to Kai's house at the edge of town.
    rect(grid,25,16,18,3,":")
    rect(grid,40,19,3,10,":")
    rect(grid,33,28,10,2,":")
    buildings = [prop("study",10,10),prop("guardhouse",24,10),prop("herbalist",10,21),prop("inn",23,20),
                 prop("gell_shop",33,15),prop("joey_home",40,15),prop("kai_house",36,27)]
    props = buildings + [prop("gate",17,5),prop("spring",22,24),prop("notice",20,12),prop("bridge",4,26)]
    props += [prop("wall",x,8) for x in [12,22]]
    props += [prop("wall",x,29) for x in [10,24]]
    props += [prop("crates",x,y) for x,y in [(5,22),(28,21),(28,11),(5,11)]]
    props += [prop("hedge",x,y) for x,y in [(12,22),(28,24),(12,11),(21,10),(28,15),(6,15),(23,28),(11,28)]]
    props += [prop("lamp",x,y) for x,y in [(13,21),(26,20),(13,10),(27,10),(15,7),(19,7),(15,28),(19,28),(32,19),(37,19),(39,27)]]
    props += [prop("hedge",x,y) for x,y in [(32,22),(32,26)]]
    # Overlapping edge canopies frame every approach without blocking lanes.
    props += [prop("tree",x,y) for x,y in [(3,6),(3,12),(3,18),(3,24),(3,31),(30,6),(30,14),(30,20),(30,29),(7,32),(12,33),(23,33),(28,33),(8,3),(13,3),(22,3),(28,3),(11,27),(25,28),(12,16),(25,16),(34,3),(40,3),(44,7),(44,13),(44,20),(44,26),(33,33),(39,33),(44,31),(31,24)]]
    town=dict(id="greymere",name="GREYMERE TOWN",subtitle="Above the Hollow Court",scene="res://scenes/overworld/greymere.tscn",
              rows=["".join(r) for r in grid], music_id="greymere", interior=False, props=props,
              spawn_points=dict(approach=spawn(17,29,(0,-1)),court_return=spawn(17,7),lena_return=spawn(10,22),inn_return=spawn(23,21),silas_return=spawn(10,11),
                            gell_return=spawn(33,16),joey_return=spawn(40,16),kai_return=spawn(36,28)),
              doors=[entrance("lena",10,21,"lena_house","lena_return"),entrance("inn",23,20,"inn","inn_return"),entrance("silas",10,10,"silas_study","silas_return"),
                     entrance("gell",33,15,"gell_shop","gell_return"),entrance("joey",40,15,"joey_home","joey_return"),entrance("kai",36,27,"kai_house","kai_return"),entrance("guard",24,10,"greymere","approach",True)],
              interactions=[dict(tile=[17,5],verb="Inspect",dialogue="court_entrance",kind="court"),dict(tile=[20,12],verb="Read",dialogue="notice_board")],
              npcs=[npc("Warden Almyra","elara","elara_intro",19,9),npc("Liora Sen","mira","mira_intro",14,13,(1,0)),npc("Joey","townsfolk/farmboy","toby_flavor",15,20),npc("Danfor","townsfolk/guard_sword","guard_flavor",25,12),npc("Watchman Orrin","townsfolk/guard_spear","watchman_flavor",20,6),npc("Old Ferris","townsfolk/torch_bearer","ferris_flavor",14,27),npc("Hooded Stranger","townsfolk/hooded_stranger","stranger_flavor",6,27)],
              lights=[dict(tile=[x,y],color="warm") for x,y in [(10,21),(23,20),(10,10),(24,10),(15,28),(19,28),(33,15),(40,15),(36,27)]]+[dict(tile=[17,5],color="violet")])
    rooms={}
    # Interiors share the 22x14 canvas; each room sets its own wall box so
    # a cottage reads smaller than a shop. The doormat and exit stay at x=10.
    full=(1,20)
    definitions=[
      dict(id="lena_house",name="LENA'S HOUSE",subtitle="Herbs, hearth and home",return_spawn="lena_return",walls=full,
           props=[prop("hearth",5,5),prop("jars",15,5),prop("workbench",5,8),prop("bed",16,8),prop("chest",17,10),prop("table",9,8)],
           npcs=[npc("Lena","townsfolk/herbalist_woman","wren_flavor",6,10)],
           inspect={(5,8):"Dried herbs hang above clean bottles. Everything is within easy reach."},
           lights=[(5,4),(15,8)]),
      dict(id="inn",name="GREYMERE INN",subtitle="Warmth along the road",return_spawn="inn_return",walls=full,
           props=[prop("hearth",5,4),prop("counter",14,6),prop("jars",15,3),prop("table",5,9),prop("table",14,10),prop("crates",17,10),prop("bed",17,4)],
           npcs=[npc("Goodwife Senna","townsfolk/elder_woman","senna_flavor",12,4),npc("Joey","townsfolk/farmboy","toby_flavor",7,10)],
           inspect={(14,6):"The timber smells of smoke and spilled ale. Someone has set out fresh mugs."},
           lights=[(5,4),(15,8)]),
      dict(id="silas_study",name="SILAS'S STUDY",subtitle="Old papers. Older questions.",return_spawn="silas_return",walls=full,
           props=[prop("books",5,5),prop("books",10,5),prop("books",15,5),prop("desk",8,8),prop("bed",17,8),prop("chest",4,11),prop("jars",15,10)],
           npcs=[npc("Elder Silas","townsfolk/village_elder","kassian_flavor",10,9)],
           inspect={(8,8):"Old maps lie beneath fresh notes. Several passages have been carefully covered."},
           lights=[(5,4),(15,8)]),
      dict(id="gell_shop",name="GELL'S SHOP",subtitle="Goods from everywhere, says Gell",return_spawn="gell_return",walls=full,
           props=[prop("counter",9,6),prop("books",4,5),prop("books",16,5),prop("jars",15,9),prop("crates",4,10),prop("crates",17,10),prop("chest",6,10)],
           npcs=[npc("Gell","townsfolk/farmhand_capped","pell_flavor",11,5)],
           inspect={(9,6):"Gell's ledger lies open beside a stack of Civara broadsheets he insists are recent.",
                    (15,9):"Lamp oil, salt, needles and thread, each priced in Gell's careful hand.",
                    (16,5):"Wares from passing merchants. Gell can say where each one was made, accurately or not."},
           lights=[(9,4),(15,7)]),
      dict(id="joey_home",name="JOEY'S HOME",subtitle="Never quite tidy",return_spawn="joey_return",walls=(3,16),
           props=[prop("hearth",6,4),prop("bed",13,5),prop("bed",16,5),prop("table",10,8),prop("chest",5,10),prop("crates",16,10),prop("jars",6,8)],
           npcs=[],
           inspect={(10,8):"A deck of cards, a half-finished wager slip and three mugs nobody has washed.",
                    (5,10):"The lid won't quite close over the things Joey swears he found.",
                    (6,4):"The fire is banked low. Joey's ma keeps a pot on it whatever the hour."},
           lights=[(6,3),(12,7)]),
      dict(id="kai_house",name="KAI'S HOUSE",subtitle="Home",return_spawn="kai_return",walls=(4,14),
           props=[prop("hearth",7,4),prop("bed",15,5),prop("table",10,7),prop("chest",15,9),prop("books",6,9),prop("workbench",13,10)],
           npcs=[],
           inspect={(15,5):"Your bed. Made this morning, mostly.",
                    (15,9):"Work gloves, a spare shirt and the rope from yesterday's job.",
                    (10,7):"Bread, a knife and a note in Lena's hand: EAT SOMETHING.",
                    (13,10):"Tools for tomorrow's work, laid out the way you like them."},
           lights=[(7,3),(12,7)])]
    for room in definitions:
        id=room["id"]
        left,inner=room["walls"]
        grid=[["_" for _ in range(22)] for _ in range(14)]
        rect(grid,left,1,inner,12,"#");rect(grid,left+1,3,inner-2,9,"w")
        rect(grid,10,11,2,1,":")
        rooms[id]=dict(id=id,name=room["name"],subtitle=room["subtitle"],scene=f"res://scenes/overworld/{id}.tscn",rows=["".join(r) for r in grid],interior=True,music_id="greymere",props=room["props"],npcs=room["npcs"],spawn_points={"entrance":spawn(10,10,(0,-1))},
          doors=[dict(building_id=id,tile=[10,12],destination_location="greymere",destination_scene="res://scenes/overworld/greymere.tscn",destination_spawn=room["return_spawn"],return_spawn="entrance",locked=False,locked_dialogue_id="locked_door",transition_type="fade",verb="Leave")],
          interactions=[dict(tile=list(tile),verb="Inspect",text=text) for tile,text in room["inspect"].items()],
          lights=[dict(tile=list(tile),color="warm") for tile in room["lights"]])
    OUT.mkdir(exist_ok=True)
    (OUT/"locations.json").write_text(json.dumps({"revision":1,"locations":{"greymere":town,**rooms}},indent=2)+"\n")

if __name__ == "__main__": compile_world()
