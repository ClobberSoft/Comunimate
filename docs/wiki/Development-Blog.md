# Development Blog

News, behind-the-scenes notes and what's coming next for Comunimate. Newest posts first.

---

## Devlog #1: Chatting with a controller shouldn't be this hard

*v0.12.2, the first public release*

### Why Comunimate exists

I play WoW: Forever on a PlayStation 5 controller. Forever's controller support is great for questing, fighting and looting. Then someone in your group asks a question, and you're reaching for a keyboard that isn't there. Typing in chat still needs a physical keyboard.

So the goal was simple: **talk to other players without ever putting the controller down.** That became two ideas:

1. **A keyboard built for thumbs**, not a phone keyboard squeezed onto a TV.
2. **Talking into chat.** Hold a button, say it, done. Not into Discord: into party or raid chat, as text.

### The keyboard: two sticks, two halves

The first version split the keyboard down the middle, the way your thumbs already are. The left stick picks a key on the left half, the right stick on the right half, and L2 / R2 type them. Word suggestions know how WoW players actually talk ("LFM", "OOM", dungeon and class names) and learn the words you use.

The rings went through a few versions before they felt right:

- **Snap:** the stick points straight at a key. Fast, but twitchy.
- **Free:** steer a ring around. Precise, but you have to bring it back.
- **Spring:** steer precisely, and it glides home to the middle key when you let go. That one stuck, and it's the default.

### Voice, and why it needs a helper app

WoW add-ons can't touch your microphone, which is a good thing for everyone's privacy. So voice lives in a small Windows helper that sits in your system tray (the orc by your clock):

- It **sleeps until WoW is running**, then wakes up.
- Hold the mic button and it listens. Let go and it turns your speech into text **on your own PC**. Nothing goes to the cloud.
- It types the text into the game, the same way a keyboard would.

The fun part came later: **saying the channel**. "Say in party chat, we need a tank" goes to party. "Say in raid chat, pull in five" goes to raid. And since this release, "**Reply**, on my way" answers whoever whispered you last.

### The bug that taught me the most

Early on, sending a message sometimes popped up the dreaded *"has been blocked from an action only available to the Blizzard UI"*. The add-on had been opening and pressing buttons on WoW's own chat box, which WoW protects.

The fix was to stop touching it at all. Comunimate now has **its own text box** and sends messages through a **player-pressed button**, the same way a macro you click does. That's also why it can send Say and Yell outdoors and keep working during boss fights, where add-ons normally can't chat.

Another fun one: in Forever, the PS5 mic button **opens your bags**. Comunimate now claims your talk button, so it only talks.

### Mascots

Somewhere along the way the tray orc got a personality. Now **every race** has a mascot: Horde, Alliance and the new Skyborne, male and female, in **Cute, Epic and Anime** styles. That's 108 portraits. They relax while you're quiet and shout when you talk. Click yours to open the settings.

### Swipe typing

The newest and hardest feature. Like swiping on a phone, but with a stick:

- Switch Settings → Sticks to **Swipe**.
- **Hold L2, trace through a word, let go.**
- The best guess floats over the ring while you trace. If it's wrong, D-Right swaps in the next guess.
- It adds spaces, capitals and apostrophes for you (`dont` → **don't**).
- A glowing trail follows the ring, in any of eight colors or your **class color**.

In testing against thousands of simulated stick swipes, it gets the word right first about 95% of the time. Real thumbs will tell the real story, so please tell me which words it misses.

### What's next

- **CurseForge.** The add-on is heading there next, with the voice helper still on GitHub.
- **Swipe polish:** accepting a word without letting go, deleting a whole swiped word in one press, and next-word predictions.
- **Your ideas.** That's what the [Issues](https://github.com/ClobberSoft/Comunimate/issues/new/choose) page is for.

Thanks for trying Comunimate. See you in chat.

*ClobberSoft*
