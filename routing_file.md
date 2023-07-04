{
"code": 200,
"data": {
    "altitude": 76,
    "altitude_info": {
      "slope": 0.18,
      "steps_info": [array of step altitude info]
    }
    "climb": 160,
    "dots_angle": 90,
    "img_url": "http://static.rfsvr.com/navigation/1682261959_5176_3483.png",
    "name": "Ottawa",
    "nid": 3483,
    "path_point": [ array of waypoints ]
    "point_count": 7,
    "step_dots": [ array of step points]
    "steps": [ array of steps]
    "time": 3941.5474285714286,
    "total_distance": 38320.6,
    "uid": 50153247
    },
"error": "success"
}


step altitude info (1 per leg between waypoints)
{
"altitude": 17,
"altitude_info": [array of step points elevation],
"climb": 4
},

step points elevation:
{
"elevation": 57,
"lat": 45.423515,
"lng": -75.676718
},

waypoints
{
"distance": 11746.7, # in meters from previous
"duration": 6653, # in seconds from previous
"intersectionsSize": 24, # not sure
"lat": 45.59303053570188,
"lng": -75.873468107776,
"name": "Voie Verte Chelsea"
},


step points
{
"dest_type": 1, # 1 for step point, 2 for waypoint
"lat": 45.420423,
"lng": -75.683271
},

steps:
{
"distance": 47.3, # in m from previous
"turn_type": "\u5de6\u8f6c", # various based on direction
"dest_type": 1, # 1 for step point, 2 for waypoint
"instruction": "Continue left onto Voie Verte Chelsea",
"path": "ujc_vAdonwoCzCjd@",  # polyline 6
"direction": 1, # 0 = straight, 1 = left, 2 = slight left, 3 = right, 4 = slight right
"name": "12 rue something",
"duration": 20.2 # in seconds from previous
},

