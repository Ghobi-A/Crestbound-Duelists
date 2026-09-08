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
    grid = [["." for _ in range(34)] for _ in range(34)]
    for x,y,w,h in [(0,0,34,2),(0,32,34,2),(0,0,2,34),(32,0,2,34)]: rect(grid,x,y,w,h,"#")
    # Irregular central square, southern approach and upper gate staircase.
    for x,y,w,h in [(16,6,3,26),(14,13,7,10),(12,16,11,5),(8,10,18,2),(9,20,16,3),(9,10,2,14),(23,10,2,13)]:
        rect(grid,x,y,w,h,":")
    rect(grid,15,6,5,3,"^")
    # Creek beyond the west lane. The walkable bridge is explicit terrain.
    rect(grid,3,21,3,10,"~")
    rect(grid,3,25,3,2,"=")
    rect(grid,6,25,9,2,":")
    buildings = [prop("study",10,10),prop("guardhouse",24,10),prop("herbalist",10,21),prop("inn",23,20)]
    props = buildings + [prop("gate",17,5),prop("spring",22,24),prop("notice",20,12),prop("bridge",4,26)]
    props += [prop("wall",x,8) for x in [12,22]]
    props += [prop("wall",x,29) for x in [10,24]]
    props += [prop("crates",x,y) for x,y in [(5,22),(28,21),(28,11),(5,11)]]
    props += [prop("hedge",x,y) for x,y in [(12,22),(28,24),(12,11),(21,10),(28,15),(6,15),(23,28),(11,28)]]
    props += [prop("lamp",x,y) for x,y in [(13,21),(26,20),(13,10),(27,10),(15,7),(19,7),(15,28),(19,28)]]
    # Overlapping edge canopies frame every approach without blocking lanes.
    props += [prop("tree",x,y) for x,y in [(3,6),(3,12),(3,18),(3,24),(3,31),(30,6),(30,14),(30,20),(30,29),(7,32),(12,33),(23,33),(28,33),(8,3),(13,3),(22,3),(28,3),(11,27),(25,28),(12,16),(25,16)]]
    town=dict(id="greymere",name="GREYMERE TOWN",subtitle="Above the Hollow Court",scene="res://scenes/overworld/greymere.tscn",
              rows=["".join(r) for r in grid], music_id="greymere", interior=False, props=props,
              spawn_points=dict(approach=spawn(17,29,(0,-1)),court_return=spawn(17,7),lena_return=spawn(10,22),inn_return=spawn(23,21),silas_return=spawn(10,11)),
              doors=[entrance("lena",10,21,"lena_house","lena_return"),entrance("inn",23,20,"inn","inn_return"),entrance("silas",10,10,"silas_study","silas_return"),entrance("guard",24,10,"greymere","approach",True)],
              interactions=[dict(tile=[17,5],verb="Inspect",dialogue="court_entrance",kind="court"),dict(tile=[20,12],verb="Read",dialogue="notice_board")],
              npcs=[npc("Warden Almyra","elara","elara_intro",19,9),npc("Liora Sen","mira","mira_intro",14,13,(1,0)),npc("Joey","townsfolk/farmboy","toby_flavor",15,20),npc("Gell","townsfolk/farmhand_capped","pell_flavor",27,23,(-1,0)),npc("Danfor","townsfolk/guard_sword","guard_flavor",25,12),npc("Watchman Orrin","townsfolk/guard_spear","watchman_flavor",20,6),npc("Old Ferris","townsfolk/torch_bearer","ferris_flavor",14,27),npc("Hooded Stranger","townsfolk/hooded_stranger","stranger_flavor",6,27)],
              lights=[dict(tile=[x,y],color="warm") for x,y in [(10,21),(23,20),(10,10),(24,10),(15,28),(19,28)]]+[dict(tile=[17,5],color="violet")])
    rooms={}
    definitions=[
      ("lena_house","LENA'S HOUSE","Herbs, hearth and home","lena_return",[prop("hearth",5,5),prop("jars",15,5),prop("workbench",5,8),prop("bed",16,8),prop("chest",17,10),prop("table",9,8)], [npc("Lena","townsfolk/herbalist_woman","wren_flavor",6,10)]),
      ("inn","GREYMERE INN","Warmth along the road","inn_return",[prop("hearth",5,4),prop("counter",14,6),prop("jars",15,3),prop("table",5,9),prop("table",14,10),prop("crates",17,10),prop("bed",17,4)], [npc("Goodwife Senna","townsfolk/elder_woman","senna_flavor",12,4),npc("Joey","townsfolk/farmboy","toby_flavor",7,10)]),
      ("silas_study","SILAS'S STUDY","Old papers. Older questions.","silas_return",[prop("books",5,5),prop("books",10,5),prop("books",15,5),prop("desk",8,8),prop("bed",17,8),prop("chest",4,11),prop("jars",15,10)], [npc("Elder Silas","townsfolk/village_elder","kassian_flavor",10,9)])]
    for id,name,subtitle,return_spawn,props,npcs in definitions:
        grid=[["_" for _ in range(22)] for _ in range(14)]
        rect(grid,1,1,20,12,"#");rect(grid,2,3,18,9,"w")
        rect(grid,10,11,2,1,":")
        rooms[id]=dict(id=id,name=name,subtitle=subtitle,scene=f"res://scenes/overworld/{id}.tscn",rows=["".join(r) for r in grid],interior=True,music_id="greymere",props=props,npcs=npcs,spawn_points={"entrance":spawn(10,10,(0,-1))},
          doors=[dict(building_id=id,tile=[10,12],destination_location="greymere",destination_scene="res://scenes/overworld/greymere.tscn",destination_spawn=return_spawn,return_spawn="entrance",locked=False,locked_dialogue_id="locked_door",transition_type="fade",verb="Leave")],
          interactions=[dict(tile=p["tile"],verb="Inspect",text={"lena_house":"Dried herbs hang above clean bottles. Everything is within easy reach.","inn":"The timber smells of smoke and spilled ale. Someone has set out fresh mugs.","silas_study":"Old maps lie beneath fresh notes. Several passages have been carefully covered."}[id]) for p in props if p["asset"] in ["workbench","counter","desk"]],
          lights=[dict(tile=[5,4],color="warm"),dict(tile=[15,8],color="warm")])
    OUT.mkdir(exist_ok=True)
    (OUT/"locations.json").write_text(json.dumps({"revision":1,"locations":{"greymere":town,**rooms}},indent=2)+"\n")

if __name__ == "__main__": compile_world()
