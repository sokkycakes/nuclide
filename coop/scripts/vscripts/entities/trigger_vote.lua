-- trigger_vote (Sven Co-op): asks every player a yes/no question.
--   message  the question
--   frags    seconds the vote stays open (default 30)
--   health   percent of the votes cast that must be yes (default 51)
--   target   fired when the vote passes
--   netname  fired when it fails
--   noise    fired when nobody votes
-- The vote shows in the chat area like any callvote; players answer with
-- "vote yes" and "vote no".

keys = Sven.Keys(self)

voteActivator = nil

function InputUse()
	voteActivator = activator
	local text = keys.message or "Vote"
	local seconds = Sven.Number(keys, "frags", 30)
	if QC.Call("Vote_ScriptStart", self, text, seconds) == 0 then
		printl("[sven] trigger_vote " .. tostring(keys.targetname) .. ": another vote is running")
	end
end

-- called by the server's vote code when the vote closes
function OnVoteEnded(yes, no, players)
	yes, no = tonumber(yes) or 0, tonumber(no) or 0
	local needed = Sven.Number(keys, "health", 51)
	local outcome

	if yes + no == 0 then
		outcome = keys.noise
	elseif yes * 100 >= needed * (yes + no) then
		outcome = keys.target
	else
		outcome = keys.netname
	end

	printl(string.format("[sven] trigger_vote %s: %d yes, %d no, needs %d%% -> %s",
		tostring(keys.targetname), yes, no, needed, tostring(outcome)))
	Sven.Fire(outcome, voteActivator)
end
