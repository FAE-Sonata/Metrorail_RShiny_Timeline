# -*- coding: utf-8 -*-
import http.client, urllib.request, urllib.parse, urllib.error
import json, pandas as pd

def obtain_headers(api_key):
    headers = {
        # Request headers
        'api_key': api_key,
    }
    return headers

def obtain_station_order(headers, code1, code2):
    params = urllib.parse.urlencode({
        # Request parameters
        'FromStationCode': code1,
        'ToStationCode': code2,
    })
    
    try:
        conn = http.client.HTTPSConnection('api.wmata.com')
        conn.request("GET", f"/Rail.svc/json/jPath?{params}", "{body}", headers)
        response = conn.getresponse()
        data = response.read()
        loaded = json.loads(data)
        lst_stations = loaded['Path']
        conn.close()
        return(pd.DataFrame(lst_stations))
    except Exception as e:
        print(f"[Errno {e.errno}] {e.strerror}")

with open("wmata_api_key.txt") as key_file:
    wmata_key=key_file.read()
    headers=obtain_headers(wmata_key)

termini_df = pd.read_csv("Termini_codes.csv")
assert all(pd.notna(termini_df['Termini1_Code'])) and all(pd.notna(termini_df[
    'Termini2_Code']))
NUM_LINES = termini_df.shape[0]
termini_ES = list(termini_df['Termini1_Code'])
termini_WN = list(termini_df['Termini2_Code'])
assert(len(termini_ES) == NUM_LINES and len(termini_WN) == NUM_LINES)

lst_lines = [obtain_station_order(headers, termini_ES[k], termini_WN[k]) for k in
             range(NUM_LINES)]
df_full_line = pd.concat(lst_lines)
df_full_line = df_full_line.replace([0], [None])
df_full_line.to_csv('api_lines_in_travel_order.csv', sep=',', index=False)