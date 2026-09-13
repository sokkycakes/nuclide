import { h } from 'preact';
import lockArtwork from '../../assets/guest-lock.svg';

export function GuestLock() {
  return <div id="GuestLock" className="guest-lock" role="note" data-figma-node="109:10">
    <img src={lockArtwork} alt="" width="122.038" height="155.382"/>
    <p>Lobby settings locked to Host.</p>
  </div>;
}
