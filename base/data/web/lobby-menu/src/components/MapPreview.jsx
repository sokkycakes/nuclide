import { h } from 'preact';
import { mapTitle } from '../model';

export function MapPreview({ snapshot: s }) {
  return <section className="map-preview" aria-label="Selected map" data-figma-node="72:184">
    <div className="map-summary">
      <div id="LblSummaryLine0">{s.ruleset || 'Waiting for settings'}</div>
      <div id="LblSummaryLine1">{s.timelimit !== '' ? (Number(s.timelimit) ? s.timelimit + ' minute time limit' : 'No time limit') : ''}</div>
      <div id="LblSummaryLine2">{s.fraglimit !== '' ? (Number(s.fraglimit) ? s.fraglimit + ' frag limit' : 'No frag limit') : ''}</div>
    </div>
    <h1 id="ImgLevelImage">{mapTitle(s.map)}</h1>
  </section>;
}
