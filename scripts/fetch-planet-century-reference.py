#!/usr/bin/env python3
"""Refresh the pinned JPL Horizons monthly planet geometry references (1926–2126).

Run from the repository root. Tests consume the saved file offline.
Columns: NAIF ID, JD(UT), illumination %, planetodetic sub-observer latitude,
subsolar position angle, north-pole position angle, astrometric RA, DEC (degrees).
Horizons pole/subsolar angles are true-of-date; RA/DEC are ICRF/J2000.
"""
from pathlib import Path
import urllib.request,urllib.parse,json
folder=Path('Documentation/DesignReview/Planetarium/CenturyAccuracy');folder.mkdir(parents=True,exist_ok=True)
rows=[]
for body in [199,299,499,599,699,799,899]:
 p={'format':'json','COMMAND':str(body),'OBJ_DATA':'NO','MAKE_EPHEM':'YES','EPHEM_TYPE':'OBSERVER','CENTER':'500@399','START_TIME':"'1926-09-20'",'STOP_TIME':"'2126-09-20'",'STEP_SIZE':"'1 MO'",'QUANTITIES':"'1,10,14,16,17,24'",'CSV_FORMAT':'YES','CAL_FORMAT':'JD','EXTRA_PREC':'YES','ANG_FORMAT':'DEG'}
 response=json.loads(urllib.request.urlopen('https://ssd.jpl.nasa.gov/api/horizons.api?'+urllib.parse.urlencode(p),timeout=120).read())
 result=response.get('result','')
 if '$$SOE' not in result: raise RuntimeError(response)
 part=result.split('$$SOE')[1].split('$$EOE')[0]
 for line in part.strip().splitlines():
  x=[x.strip() for x in line.split(',')]
  rows.append([body,float(x[0]),float(x[5]),float(x[7]),float(x[8]),float(x[10]),float(x[3]),float(x[4])])
 (folder/('horizons-'+str(body)+'-header.txt')).write_text(result.split('$$SOE')[0])
 print(body,len(part.strip().splitlines()),flush=True)
(folder/'monthly-reference.json').write_text(json.dumps(rows,separators=(',',':')))
