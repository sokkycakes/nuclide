import { h } from 'preact';
import { mapTitle, rulesetTitle, serverSummary } from '../model';

export function MapPreview({ snapshot: s }) {
  return <section className="map-preview" aria-label="Selected map" data-figma-node="72:184">
    <div className="map-summary">
      <div id="LblSummaryLine0">{s.ruleset ? rulesetTitle(s.ruleset, s) : 'Waiting for settings'}</div>
      <div id="LblSummaryLine1">{s.timelimit !== '' ? (Number(s.timelimit) ? s.timelimit + ' minute time limit' : 'No time limit') : ''}</div>
      <div id="LblSummaryLine2">{s.fraglimit !== '' ? (Number(s.fraglimit) ? s.fraglimit + ' frag limit' : 'No frag limit') : ''}</div>
      <div id="LblSummaryLine3">{s.active && s.hosting ? serverSummary(s) : ''}</div>
    </div>
    <h1 id="ImgLevelImage">{mapTitle(s.map, s)}</h1>
  </section>;
}
