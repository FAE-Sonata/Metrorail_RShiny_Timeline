# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""

import http.client, urllib.request, urllib.parse, urllib.error
import json, pandas as pd

def obtain_headers(api_key):
    headers = {
        # Request headers
        'api_key': api_key,
    }
    return headers

def obtain_stations(headers, line_code):
    params = urllib.parse.urlencode({
        # Request parameters
        'LineCode': line_code,
    })
    
    try:
        conn = http.client.HTTPSConnection('api.wmata.com')
        conn.request("GET", f"/Rail.svc/json/jStations?{params}", "{body}", headers)
        response = conn.getresponse()
        data = response.read()
        loaded = json.loads(data.decode())
        conn.close()
        res_dict = loaded['Stations']
        # remove Address key as its value is an unnecessary dict
        for st in res_dict:
            if not('Address' in st):
                continue
            del st['Address']
        res = pd.DataFrame.from_dict(res_dict)
        res['queriedLine'] = line_code
        return res
    except Exception as e:
        print(f"[Errno {e.errno}] {e.strerror}")
        return None

with open("wmata_api_key.txt") as key_file:
    wmata_key=key_file.read()
    headers=obtain_headers(wmata_key)

headers=obtain_headers(wmata_key)
line_codes=["RD", "OR", "BL", "GR", "YL", "SV"]
full_station_list=[obtain_stations(headers, s) for s in line_codes]
df_full_station=pd.concat(full_station_list)
df_full_station.to_csv('api_stations.csv', sep=',', index=False)