import Foundation

// MARK: - Content Models

struct HandbookChapter: Identifiable {
    let id: Int
    let number: String
    let title: String
    let pillLabels: [String]
	let sections: [HandbookSection]
}

struct HandbookSection: Identifiable {
    let id: String
    let title: String
    let blocks: [ContentBlock]
}

enum ContentBlock {
    case paragraph(String)
    case subheading(String)
    case subheading2(String)          // h4 equivalent
    case bulletList([BulletItem])
    case checkUnderstand([String])
    case blockquote(String)
    case dataTable(headers: [String], rows: [[String]])
}

struct BulletItem: Identifiable {
    let id = UUID()
    let text: AttributedContent  // supports bold inline
    let subItems: [String]

    init(_ text: String, subItems: [String] = []) {
        self.text = AttributedContent(raw: text)
        self.subItems = subItems
    }
}

struct AttributedContent {
    let raw: String
}

// MARK: - Handbook Data

struct HandbookData {

    static let chapters: [HandbookChapter] = [
        chapter1, chapter2, chapter3, chapter4, chapter5
    ]

    // MARK: Chapter 1
    static let chapter1 = HandbookChapter(
        id: 0,
        number: "Chapter 1",
        title: "Values & Principles of the UK",
        pillLabels: ["Values & Principles", "Becoming a Resident", "The Life in the UK Test"],
        sections: [
            HandbookSection(id: "c1s0", title: "The Values and Principles of the UK", blocks: [
                .paragraph("British society is founded on fundamental values and principles which all those living in the UK should respect and support. These values are reflected in the responsibilities, rights and privileges of being a British citizen or permanent resident. There is no place in British society for extremism or intolerance."),
                .subheading("Fundamental Principles"),
                .paragraph("The fundamental principles of British life include:"),
                .bulletList([BulletItem("Democracy"), BulletItem("The rule of law"), BulletItem("Individual liberty"), BulletItem("Tolerance of those with different faiths and beliefs"), BulletItem("Participation in community life")]),
                .subheading("The Citizenship Pledge"),
                .paragraph("As part of the citizenship ceremony, new citizens pledge to uphold these values:"),
                .blockquote("'I will give my loyalty to the United Kingdom and respect its rights and freedoms. I will uphold its democratic values. I will observe its laws faithfully and fulfil my duties and obligations as a British citizen.'"),
                .subheading("Your Responsibilities"),
                .bulletList([BulletItem("Respect and obey the law"), BulletItem("Respect the rights of others, including their right to their own opinions"), BulletItem("Treat others with fairness"), BulletItem("Look after yourself and your family"), BulletItem("Look after the area in which you live and the environment")]),
                .subheading("What the UK Offers"),
                .bulletList([BulletItem("Freedom of belief and religion"), BulletItem("Freedom of speech"), BulletItem("Freedom from unfair discrimination"), BulletItem("A right to a fair trial"), BulletItem("A right to join in the election of a government")]),
                .checkUnderstand(["The origin of the values underlying British society", "The fundamental principles of British life", "The responsibilities and freedoms which come with permanent residence", "The process of becoming a permanent resident or citizen"])
            ]),
            HandbookSection(id: "c1s1", title: "Becoming a Permanent Resident", blocks: [
                .paragraph("To apply to become a permanent resident or citizen of the UK, you will need to speak and read English and have a good understanding of life in the UK."),
                .subheading("Ways to Meet the Requirements"),
                .bulletList([
                    BulletItem("**Take the Life in the UK test.** Questions are written at ESOL Entry Level 3, so no separate English test is needed. Those on work visas (Tier 1 and Tier 2) normally must pass this test."),
                    BulletItem("**Pass an ESOL course in English with Citizenship.** Required if your English is below ESOL Entry Level 3.")
                ]),
                .subheading("From October 2013 Onwards"),
                .paragraph("For settlement or permanent residence, you must pass the Life in the UK test AND provide acceptable evidence of English speaking and listening skills at B1 of the Common European Framework (equivalent to ESOL Entry Level 3).")
            ]),
            HandbookSection(id: "c1s2", title: "Taking the Life in the UK Test", blocks: [
                .paragraph("The test consists of 24 questions about important aspects of life in the UK. Questions are based on ALL parts of the handbook."),
                .subheading("Test Details"),
                .bulletList([
                    BulletItem("Usually taken in English (special arrangements for Welsh or Scottish Gaelic)"),
                    BulletItem("Must be taken at a registered and approved test centre — around 60 centres in the UK"),
                    BulletItem("Booking only available online at www.lifeintheuktest.gov.uk"),
                    BulletItem("Take identification and proof of address to the test")
                ]),
                .subheading("How to Use This Handbook"),
                .paragraph("Everything you need to know to pass the test is included here. The questions cover the whole book including this introduction. The 'Check that you understand' boxes highlight key points but knowing only those is not enough — study the entire book."),
                .subheading("Where to Find More Information"),
                .bulletList([
                    BulletItem("www.ukba.homeoffice.gov.uk — application process and forms"),
                    BulletItem("www.lifeintheuktest.gov.uk — test information and booking"),
                    BulletItem("www.gov.uk — information about ESOL courses")
                ])
            ])
        ]
    )

    // MARK: Chapter 2
    static let chapter2 = HandbookChapter(
        id: 1,
        number: "Chapter 2",
        title: "What is the UK?",
        pillLabels: ["The UK Nations"],
        sections: [
            HandbookSection(id: "c2s0", title: "What is the UK?", blocks: [
                .paragraph("The UK is made up of England, Scotland, Wales and Northern Ireland. The rest of Ireland is an independent country."),
                .paragraph("The official name is the United Kingdom of Great Britain and Northern Ireland. 'Great Britain' refers only to England, Scotland and Wales — not Northern Ireland."),
                .subheading("Crown Dependencies & Overseas Territories"),
                .paragraph("The Channel Islands and the Isle of Man are closely linked with the UK but are not part of it. These are called 'Crown dependencies' and have their own governments. British overseas territories such as St Helena and the Falkland Islands are also linked to the UK but not part of it."),
                .subheading("How the UK is Governed"),
                .paragraph("The UK is governed by the Parliament sitting in Westminster. Scotland, Wales and Northern Ireland also have parliaments or assemblies of their own with devolved powers in defined areas."),
                .checkUnderstand(["The different countries that make up the UK"])
            ])
        ]
    )

    // MARK: Chapter 3
    static let chapter3 = HandbookChapter(
        id: 2,
        number: "Chapter 3",
        title: "A Long & Illustrious History",
        pillLabels: ["Early Britain", "Middle Ages", "Tudors & Stuarts", "A Global Power", "20th Century", "Britain Since 1945"],
        sections: [
            HandbookSection(id: "c3s0", title: "Early Britain", blocks: [
                .paragraph("The first people to live in Britain were hunter-gatherers in the Stone Age. Britain only became permanently separated from the continent by the Channel about 10,000 years ago. The first farmers arrived 6,000 years ago and built monuments including Stonehenge in Wiltshire and Skara Brae on Orkney — the best preserved prehistoric village in northern Europe."),
                .subheading("The Romans"),
                .paragraph("Julius Caesar led an unsuccessful invasion in 55 BC. In AD 43, Emperor Claudius successfully invaded. Boudicca, queen of the Iceni, famously resisted — her statue stands on Westminster Bridge. Hadrian's Wall was built to keep out the Picts. The Romans remained for 400 years, building roads, establishing law, and introducing Christianity."),
                .subheading("The Anglo-Saxons"),
                .paragraph("The Roman army left Britain in AD 410. The Angles, Saxons and Jutes invaded; their languages form the basis of modern English. By AD 600, Anglo-Saxon kingdoms were established. Christianity spread through St Patrick, St Columba (who founded a monastery on Iona), and St Augustine — the first Archbishop of Canterbury."),
                .subheading("The Vikings"),
                .paragraph("Vikings from Denmark and Norway first raided Britain in AD 789, then began to settle. King Alfred the Great defeated them. In the north, Kenneth MacAlpin united the Scots and the name 'Scotland' began to be used."),
                .subheading("The Norman Conquest"),
                .paragraph("In 1066, William, Duke of Normandy, defeated Harold at the Battle of Hastings — the last successful foreign invasion of England. William became king (William the Conqueror). The battle is depicted in the Bayeux Tapestry. William created the Domesday Book, a survey of all land and property in England."),
                .checkUnderstand(["The history of the UK before the Romans", "The impact of the Romans on British society", "The different groups that invaded after the Romans", "Importance of the Norman invasion in 1066"])
            ]),
            HandbookSection(id: "c3s1", title: "The Middle Ages", blocks: [
                .paragraph("The Middle Ages (or medieval period) lasted from the Norman Conquest until about 1485 — a time of almost constant war."),
                .subheading("War at Home and Abroad"),
                .paragraph("In 1284, King Edward I introduced the Statute of Rhuddlan, annexing Wales. In 1314, Robert the Bruce defeated the English at the Battle of Bannockburn. The Hundred Years War with France lasted 116 years; the Battle of Agincourt (1415) saw Henry V defeat the French against the odds."),
                .subheading("The Black Death"),
                .paragraph("In 1348, the Black Death killed one third of England's population. Labour shortages led to peasants demanding higher wages and new social classes emerging, including the gentry."),
                .subheading("Legal and Political Changes"),
                .paragraph("In 1215, King John was forced to agree to the Magna Carta, establishing that even the king was subject to the law. Parliament developed with two Houses: the House of Lords and the House of Commons."),
                .subheading("A Distinct Identity"),
                .paragraph("Norman French and Anglo-Saxon gradually combined into one English language. Geoffrey Chaucer wrote The Canterbury Tales — one of the first books printed by William Caxton, England's first printer."),
                .subheading("The Wars of the Roses"),
                .paragraph("From 1455, civil war was fought between the House of Lancaster (red rose) and the House of York (white rose). At the Battle of Bosworth Field (1485), Henry Tudor became King Henry VII. He married Elizabeth of York, uniting the families. The Tudor rose — red with a white rose inside — symbolises this union."),
                .checkUnderstand(["The wars that took place in the Middle Ages", "How Parliament began to develop", "The effects of the Black Death", "The development of English language and culture", "The Wars of the Roses and the founding of the House of Tudor"])
            ]),
            HandbookSection(id: "c3s2", title: "The Tudors and Stuarts", blocks: [
                .subheading("Henry VIII and the Reformation"),
                .paragraph("Henry VIII broke away from the Church of Rome and established the Church of England, with the king — not the Pope — appointing bishops. He married six times."),
                .subheading("The Six Wives of Henry VIII"),
                .bulletList([
                    BulletItem("**Catherine of Aragon** — divorced; mother of Mary"),
                    BulletItem("**Anne Boleyn** — executed at the Tower of London; mother of Elizabeth"),
                    BulletItem("**Jane Seymour** — gave Henry his son Edward; died shortly after birth"),
                    BulletItem("**Anne of Cleves** — German princess; divorced soon after"),
                    BulletItem("**Catherine Howard** — executed"),
                    BulletItem("**Catherine Parr** — survived Henry; remarried")
                ]),
                .subheading("Queen Elizabeth I"),
                .paragraph("Elizabeth I re-established the Church of England. She became one of England's most popular monarchs, especially after defeating the Spanish Armada in 1588."),
                .subheading("William Shakespeare (1564–1616)"),
                .paragraph("Born in Stratford-upon-Avon, Shakespeare was a playwright and actor. Famous plays include A Midsummer Night's Dream, Hamlet, Macbeth and Romeo and Juliet. The Globe Theatre in London is a modern replica of his original theatre."),
                .subheading("The English Civil War & Oliver Cromwell"),
                .paragraph("Charles I believed in the 'Divine Right of Kings'. Civil war began in 1642 between the Cavaliers (Royalists) and Roundheads (Parliament). Charles I was executed in 1649. England became a republic (the Commonwealth). Oliver Cromwell became Lord Protector until his death in 1658."),
                .subheading("The Restoration & Glorious Revolution"),
                .paragraph("In 1660, Charles II returned from exile. The Habeas Corpus Act (1679) guaranteed no one could be held prisoner unlawfully. In 1688, William of Orange was invited to invade; James II fled. The Bill of Rights (1689) confirmed Parliament's supremacy, beginning constitutional monarchy."),
                .checkUnderstand(["How and why religion changed during this period", "The importance of poetry and drama in the Elizabethan period", "The development of Parliament and the English republic", "Why there was a restoration of the monarchy", "How the Glorious Revolution happened"])
            ]),
            HandbookSection(id: "c3s3", title: "A Global Power", blocks: [
                .paragraph("The Bill of Rights established constitutional monarchy. Parliament needed ministers who could command a majority — the beginning of party politics (Whigs and Tories)."),
                .subheading("Act of Union & the Prime Minister"),
                .paragraph("In 1707, the Act of Union created the Kingdom of Great Britain. Scotland kept its legal and education systems. The first Prime Minister was Sir Robert Walpole (1721–1742)."),
                .subheading("The Enlightenment"),
                .paragraph("The 18th century saw new ideas in politics, philosophy and science. Scottish thinkers Adam Smith (economics) and David Hume (philosophy) were key figures. James Watt's work on steam power drove the Industrial Revolution."),
                .subheading("The Slave Trade"),
                .paragraph("Britain dominated the transatlantic slave trade. William Wilberforce led the abolition campaign. In 1807, trading slaves in British ships became illegal; in 1833 the Emancipation Act abolished slavery throughout the British Empire."),
                .subheading("The Victorian Age"),
                .paragraph("Queen Victoria reigned for almost 64 years (1837–1901). The British Empire grew to cover India, Australia and large parts of Africa — the largest empire the world had seen, with over 400 million people. Isambard Kingdom Brunel built the Great Western Railway. Florence Nightingale founded modern nursing. Emmeline Pankhurst founded the suffragette movement; women over 30 got the vote in 1918, and all women over 21 in 1928."),
                .checkUnderstand(["When and why Scotland joined England and Wales", "The ideas of the Enlightenment", "The importance of the Industrial Revolution", "The slave trade and when it was abolished", "The growth of the British Empire", "How democracy developed during this period"])
            ]),
            HandbookSection(id: "c3s4", title: "The 20th Century", blocks: [
                .subheading("The First World War (1914–18)"),
                .paragraph("The assassination of Archduke Franz Ferdinand on 28 June 1914 triggered the First World War. Britain was part of the Allied Powers, suffering more than 2 million casualties. The war ended on 11 November 1918."),
                .subheading("The Partition of Ireland"),
                .paragraph("After the Easter Rising of 1916 and a guerrilla war, Ireland became two countries in 1922. The six northern counties (mainly Protestant) became Northern Ireland. The rest became the Irish Free State. Ongoing conflict was known as 'the Troubles'."),
                .subheading("The Second World War (1939–45)"),
                .paragraph("Hitler invaded Poland in 1939; Britain declared war. Winston Churchill became Prime Minister in May 1940. Key events included the evacuation at Dunkirk (300,000+ soldiers rescued), the Battle of Britain (RAF victory, summer 1940), the Blitz, and D-Day on 6 June 1944. Germany surrendered in May 1945; Japan in August 1945."),
                .subheading("Alexander Fleming (1881–1955)"),
                .paragraph("Born in Scotland, Fleming discovered penicillin in 1928. Further developed by Howard Florey and Ernst Chain, by the 1940s it was in mass production. Fleming won the Nobel Prize in Medicine in 1945."),
                .checkUnderstand(["What happened during the First World War", "The partition of Ireland", "The events of the Second World War"])
            ]),
            HandbookSection(id: "c3s5", title: "Britain Since 1945", blocks: [
                .subheading("The Welfare State"),
                .paragraph("In 1945, Labour under Clement Attlee was elected. Aneurin Bevan established the National Health Service (NHS) in 1948, providing healthcare free at the point of use. A national benefits system provided 'social security' from the 'cradle to the grave'."),
                .subheading("The 1960s — Social Change"),
                .paragraph("The 'Swinging Sixties' brought growth in British fashion, cinema and pop music. The Beatles and The Rolling Stones had worldwide impact. Social laws were liberalised. Britain and France developed Concorde, the world's only supersonic commercial airliner."),
                .subheading("Great British Inventions of the 20th Century"),
                .bulletList([
                    BulletItem("**Television** — John Logie Baird (1920s)"),
                    BulletItem("**Radar** — Sir Robert Watson-Watt (1935)"),
                    BulletItem("**Computer science** — Alan Turing's Turing machine (1930s)"),
                    BulletItem("**DNA structure** discovered at British universities (1953)"),
                    BulletItem("**Jet engine** — Sir Frank Whittle (1930s)"),
                    BulletItem("**ATM/cashpoint** — James Goodfellow (1967)"),
                    BulletItem("**World Wide Web** — Sir Tim Berners-Lee (1990)")
                ]),
                .subheading("Margaret Thatcher"),
                .paragraph("Margaret Thatcher became Britain's first woman Prime Minister in 1979 and served until 1990 — the longest-serving PM of the 20th century. Her government privatised nationalised industries and imposed legal controls on trade union powers."),
                .subheading("Labour 1997–2010 & Coalition from 2010"),
                .paragraph("Tony Blair's Labour government introduced the Scottish Parliament and Welsh Assembly (1999) and signed the Good Friday Agreement in 1998. In May 2010, a Conservative–Liberal Democrat coalition under David Cameron was formed."),
                .checkUnderstand(["The establishment of the welfare state", "How life in Britain changed in the 1960s and 1970s", "British inventions of the 20th century", "Events since 1979"])
            ])
        ]
    )

    // MARK: Chapter 4
    static let chapter4 = HandbookChapter(
        id: 3,
        number: "Chapter 4",
        title: "A Modern, Thriving Society",
        pillLabels: ["The UK Today", "Religion", "Customs", "Sports", "Arts & Culture", "Leisure", "Places"],
        sections: [
            HandbookSection(id: "c4s0", title: "The UK Today", blocks: [
                .paragraph("The UK today is a diverse society. Post-war immigration means that nearly 10% of the population has a parent or grandparent born outside the UK."),
                .subheading("UK Currency"),
                .paragraph("The currency is the pound sterling (£). There are 100 pence in a pound."),
                .bulletList([BulletItem("**Coins:** 1p, 2p, 5p, 10p, 20p, 50p, £1 and £2"), BulletItem("**Notes:** £5, £10, £20, £50")]),
                .subheading("Languages and Dialects"),
                .paragraph("English has many accents and dialects. In Wales, many people speak Welsh. In parts of the Scottish Highlands, Gaelic is spoken. In Northern Ireland, some people speak Irish Gaelic."),
                .subheading("Population"),
                .dataTable(headers: ["Year", "Population"], rows: [["1600", "Just over 4 million"], ["1800", "8 million"], ["1901", "40 million"], ["1951", "50 million"], ["2010", "Just over 62 million"]]),
                .paragraph("England makes up about 84% of the total population, Wales 5%, Scotland 8%, and Northern Ireland less than 3%."),
                .checkUnderstand(["The capital cities of the UK", "What languages other than English are spoken in particular parts of the UK", "How the population of the UK has changed", "The currency of the UK"])
            ]),
            HandbookSection(id: "c4s1", title: "Religion", blocks: [
                .paragraph("The UK is historically a Christian country. In a 2009 survey, 70% of people identified as Christian. Everyone has the legal right to choose their religion, or to choose not to practise one."),
                .subheading("The Church of England"),
                .paragraph("England has a constitutional link between Church and state. The Church of England (Anglican Church) is the established state Church, existing since the Reformation in the 1530s. The monarch is its head; the Archbishop of Canterbury is its spiritual leader. In Scotland, the national Church is the Church of Scotland (Presbyterian). There is no established Church in Wales or Northern Ireland."),
                .subheading("Patron Saints' Days"),
                .bulletList([BulletItem("**1 March** — St David's Day (Wales)"), BulletItem("**17 March** — St Patrick's Day (Northern Ireland)"), BulletItem("**23 April** — St George's Day (England)"), BulletItem("**30 November** — St Andrew's Day (Scotland)")]),
                .paragraph("Only Scotland and Northern Ireland have their patron saint's day as an official holiday."),
                .checkUnderstand(["The different religions practised in the UK", "That the Church of England is the established Church in England", "About the patron saints"])
            ]),
            HandbookSection(id: "c4s2", title: "Customs and Traditions", blocks: [
                .subheading("Main Christian Festivals"),
                .bulletList([BulletItem("**Christmas Day (25 December)** — Public holiday. Special meal, gifts, cards, tree decorations. Boxing Day (26 Dec) is also a public holiday."), BulletItem("**Easter (March or April)** — Good Friday and Easter Monday are public holidays. 40 days before Easter is Lent; the day before Lent is Shrove Tuesday (Pancake Day).")]),
                .subheading("Other Religious Festivals"),
                .bulletList([BulletItem("**Diwali** (October/November) — Hindu and Sikh Festival of Lights"), BulletItem("**Hannukah** (November/December) — Jewish 8-day festival of religious freedom"), BulletItem("**Eid al-Fitr** — Muslim celebration at the end of Ramadan"), BulletItem("**Vaisakhi (14 April)** — Sikh festival celebrating the founding of the Khalsa")]),
                .subheading("Other Traditions"),
                .bulletList([BulletItem("**New Year (1 Jan)** — In Scotland, 31 Dec is Hogmanay; 2 Jan is also a public holiday"), BulletItem("**April Fool's Day (1 April)** — People play jokes until midday"), BulletItem("**Halloween (31 October)** — 'Trick or treat', costumes, pumpkin lanterns"), BulletItem("**Bonfire Night (5 November)** — Fireworks commemorating the failed Gunpowder Plot of 1605"), BulletItem("**Remembrance Day (11 November)** — Two-minute silence at 11am; poppies worn to honour the war dead")]),
                .checkUnderstand(["The main Christian festivals celebrated in the UK", "Other religious festivals important in the UK", "What a bank holiday is"])
            ]),
            HandbookSection(id: "c4s3", title: "Sports", blocks: [
                .paragraph("Many famous sports — including cricket, football, lawn tennis, golf and rugby — began in Britain. The UK hosted the Olympic Games in 1908, 1948 and 2012."),
                .subheading("Cricket"),
                .paragraph("Cricket originated in England and is now played globally. Games can last up to five days. The most famous competition is The Ashes — a Test series between England and Australia."),
                .subheading("Football"),
                .paragraph("Football is the UK's most popular sport. The English Premier League attracts a huge international audience. England's only major tournament victory was the 1966 World Cup, hosted in the UK."),
                .subheading("Rugby"),
                .paragraph("Rugby originated in England in the early 19th century. There are two types: union and league. The most famous competition is the Six Nations Championship."),
                .subheading("Other Sports"),
                .bulletList([BulletItem("**Horse racing** — Famous events: Royal Ascot, the Grand National at Aintree"), BulletItem("**Golf** — Modern game traced to 15th-century Scotland; St Andrews is 'the home of golf'"), BulletItem("**Tennis** — Wimbledon Championships is the oldest tennis tournament in the world, the only Grand Slam played on grass"), BulletItem("**Motor racing** — A Formula 1 Grand Prix is held in the UK each year")]),
                .checkUnderstand(["Which sports are particularly popular in the UK", "Some of the major sporting events each year"])
            ]),
            HandbookSection(id: "c4s4", title: "Arts and Culture", blocks: [
                .subheading("Music"),
                .paragraph("The Proms is an eight-week summer season of orchestral music, organised by the BBC since 1927. The Last Night of the Proms is broadcast on television. British pop music has had enormous global impact since the 1960s, with The Beatles and Rolling Stones continuing to influence music worldwide."),
                .subheading("Theatre"),
                .paragraph("London's West End ('Theatreland') is world-famous. The Mousetrap by Agatha Christie has been running since 1952 — the longest-running show in history. The Edinburgh Festival Fringe is a major international arts event held every summer."),
                .subheading("Notable British Authors"),
                .bulletList([BulletItem("**Jane Austen** (1775–1817) — Pride and Prejudice, Sense and Sensibility"), BulletItem("**Charles Dickens** (1812–70) — Oliver Twist, Great Expectations"), BulletItem("**Arthur Conan Doyle** (1859–1930) — Sherlock Holmes stories"), BulletItem("**J K Rowling** (1965–) — Harry Potter series")]),
                .subheading("Architecture"),
                .paragraph("The UK has a rich architectural heritage from medieval cathedrals (Durham, Canterbury, Salisbury) to modern architects including Sir Norman Foster, Lord Rogers and Dame Zaha Hadid."),
                .checkUnderstand(["Some of the major arts and culture events in the UK", "How achievements in arts and culture are formally recognised", "Important figures in British literature"])
            ]),
            HandbookSection(id: "c4s5", title: "Leisure", blocks: [
                .subheading("Popular Activities"),
                .bulletList([BulletItem("**Gardening** — Famous gardens include Kew Gardens, Sissinghurst, Bodnant Garden in Wales"), BulletItem("**Cooking** — Wide variety of food reflects the UK's diverse heritage"), BulletItem("**Shopping** — Most shops open seven days a week")]),
                .subheading("Traditional Foods"),
                .bulletList([BulletItem("**England** — Roast beef with Yorkshire pudding; fish and chips"), BulletItem("**Wales** — Welsh cakes (flour, dried fruits, spices)"), BulletItem("**Scotland** — Haggis"), BulletItem("**Northern Ireland** — Ulster fry")]),
                .subheading("National Flowers"),
                .bulletList([BulletItem("**England** — the rose"), BulletItem("**Scotland** — the thistle"), BulletItem("**Wales** — the daffodil"), BulletItem("**Northern Ireland** — the shamrock")]),
                .subheading("Television"),
                .paragraph("Everyone in the UK with a TV must have a television licence. The licence fee funds the BBC — the largest broadcaster in the world and the only wholly state-funded media organisation independent of government.")
            ]),
            HandbookSection(id: "c4s6", title: "Places of Interest", blocks: [
                .subheading("UK Landmarks"),
                .bulletList([
                    BulletItem("**Big Ben** — The great bell of the clock at the Houses of Parliament, London. Over 150 years old. The clock tower is officially named 'Elizabeth Tower'."),
                    BulletItem("**The Eden Project** — Cornwall; giant greenhouse biomes housing plants from around the world"),
                    BulletItem("**Edinburgh Castle** — Dominates the Edinburgh skyline; history dating back to the early Middle Ages"),
                    BulletItem("**The Giant's Causeway** — Northern Ireland; volcanic rock columns formed about 50 million years ago"),
                    BulletItem("**The Lake District** — England's largest national park (885 sq miles); Windermere is the largest lake"),
                    BulletItem("**London Eye** — Ferris wheel on the South Bank, 443 feet (135m) tall"),
                    BulletItem("**Snowdonia** — National park in North Wales; Snowdon is the highest mountain in Wales"),
                    BulletItem("**Tower of London** — First built by William the Conqueror in 1066; home to the Crown Jewels")
                ]),
                .checkUnderstand(["Some of the ways people in the UK spend their leisure time", "What the television licence is and how it funds the BBC", "Some of the places of interest to visit in the UK"])
            ])
        ]
    )

    // MARK: Chapter 5
    static let chapter5 = HandbookChapter(
        id: 4,
        number: "Chapter 5",
        title: "UK Government, Law & Your Role",
        pillLabels: ["Democracy", "The Constitution", "The Government", "International", "The Law", "The Courts", "Fundamental Rights", "Your Community"],
        sections: [
            HandbookSection(id: "c5s0", title: "The Development of British Democracy", blocks: [
                .paragraph("Democracy is a system of government where the whole adult population gets a say. At the turn of the 19th century, only men over 21 who owned property could vote."),
                .subheading("The Chartists (1830s–1840s)"),
                .bulletList([BulletItem("Every man to have the vote"), BulletItem("Elections every year"), BulletItem("Equal regions in the electoral system"), BulletItem("Secret ballots"), BulletItem("Any man to be able to stand as an MP"), BulletItem("MPs to be paid")]),
                .paragraph("By 1918, most of these reforms had been adopted. Women over 30 got the vote in 1918. In 1928, men and women over 21 could vote. In 1969, the voting age was lowered to 18."),
                .checkUnderstand(["How democracy has developed in the UK"])
            ]),
            HandbookSection(id: "c5s1", title: "The British Constitution", blocks: [
                .paragraph("Britain's constitution is 'unwritten' — not set out in a single document, but developed over hundreds of years through law, custom and convention."),
                .subheading("Constitutional Institutions"),
                .bulletList([BulletItem("The Monarchy"), BulletItem("Parliament (House of Commons and House of Lords)"), BulletItem("The Prime Minister"), BulletItem("The Cabinet"), BulletItem("The Judiciary (courts)"), BulletItem("The Police"), BulletItem("The Civil Service"), BulletItem("Local Government")]),
                .subheading("The Monarchy"),
                .paragraph("The UK is a constitutional monarchy. The monarch appoints the government chosen by democratic election and has important ceremonial roles. The National Anthem is 'God Save the Queen'. New citizens swear or affirm loyalty to the monarch as part of the citizenship ceremony."),
                .subheading("Parliament"),
                .paragraph("The UK has a parliamentary democracy with constituencies. The House of Commons is the elected chamber — the more important of the two. The House of Lords (peers, not elected) checks laws passed by the Commons. The Speaker chairs debates in the Commons, remaining neutral."),
                .subheading("Elections"),
                .paragraph("MPs are elected through 'first past the post' — the candidate with the most votes wins. European Parliament elections use proportional representation."),
                .checkUnderstand(["What a constitution is and how the UK's differs from most countries", "The role of the monarch", "The role of the House of Commons and House of Lords", "What the Speaker does", "How the UK elects MPs"])
            ]),
            HandbookSection(id: "c5s2", title: "The Government", blocks: [
                .subheading("The Prime Minister"),
                .paragraph("The PM is the leader of the party in power. The official residence is 10 Downing Street; the country home is Chequers."),
                .subheading("The Cabinet"),
                .bulletList([BulletItem("**Chancellor of the Exchequer** — responsible for the economy"), BulletItem("**Home Secretary** — responsible for crime, policing and immigration"), BulletItem("**Foreign Secretary** — responsible for foreign relations")]),
                .paragraph("The cabinet meets weekly and makes important decisions about government policy."),
                .subheading("The Opposition & Shadow Cabinet"),
                .paragraph("The second-largest party is 'the opposition'. The leader appoints a shadow cabinet to challenge government policies. Prime Minister's Questions takes place every week while Parliament is sitting."),
                .subheading("Devolved Administrations"),
                .bulletList([BulletItem("**Welsh Assembly** (Cardiff) — 60 Assembly members; can pass laws in 20 areas"), BulletItem("**Scottish Parliament** (Edinburgh, Holyrood) — 129 MSPs; can legislate on health, education, civil/criminal law, and has tax-raising powers"), BulletItem("**Northern Ireland Assembly** (Belfast, Stormont) — 108 MLAs; can decide on education, agriculture, health and social services")]),
                .checkUnderstand(["The role of the PM, cabinet, opposition and shadow cabinet", "Who the main political parties are", "The role of the civil service and local government", "The powers of devolved governments"])
            ]),
            HandbookSection(id: "c5s3", title: "The UK and International Institutions", blocks: [
                .subheading("The Commonwealth"),
                .paragraph("An association of countries (mostly former British Empire) working towards shared goals of democracy and development. Currently 54 member states. The Queen is the ceremonial head."),
                .subheading("The European Union"),
                .paragraph("The EU was set up by six countries with the Treaty of Rome on 25 March 1957. The UK joined in 1973. EU law is legally binding in all member states."),
                .subheading("The United Nations"),
                .paragraph("The UN was set up after the Second World War to prevent war and promote international peace. The UK is one of five permanent members of the UN Security Council."),
                .subheading("NATO"),
                .paragraph("The North Atlantic Treaty Organization is a group of European and North American countries that have agreed to help each other if attacked and to maintain peace."),
                .checkUnderstand(["What the Commonwealth is and its role", "Other international organisations of which the UK is a member"])
            ]),
            HandbookSection(id: "c5s4", title: "Respecting the Law", blocks: [
                .paragraph("Every person in the UK receives equal treatment under the law."),
                .subheading("Types of Law"),
                .bulletList([BulletItem("**Criminal law** — crimes investigated by police and punished by courts"), BulletItem("**Civil law** — used to settle disputes between individuals or groups")]),
                .subheading("Examples of Criminal Laws"),
                .bulletList([BulletItem("**Weapons** — illegal to carry any weapon, even for self-defence"), BulletItem("**Drugs** — selling or buying heroin, cocaine, ecstasy and cannabis is illegal"), BulletItem("**Racial crime** — causing harassment due to religion or ethnic origin is a criminal offence"), BulletItem("**Tobacco** — illegal to sell to anyone under 18"), BulletItem("**Alcohol** — illegal to sell to or buy for anyone under 18")]),
                .subheading("The Police"),
                .paragraph("The police protect life and property, keep the peace, and prevent and detect crime. They are organised into forces headed by Chief Constables and are independent of the government."),
                .checkUnderstand(["The difference between civil and criminal law", "The duties of the police", "The possible terrorist threats facing the UK"])
            ]),
            HandbookSection(id: "c5s5", title: "The Role of the Courts", blocks: [
                .subheading("Criminal Courts"),
                .bulletList([BulletItem("**Magistrates' Court** (England, Wales, N. Ireland) / **Justice of the Peace Court** (Scotland) — minor criminal cases"), BulletItem("**Crown Court** (England, Wales, N. Ireland) / **Sheriff Court** (Scotland) — serious offences, tried before a judge and jury. A jury has 12 members in England/Wales/N. Ireland, and 15 in Scotland."), BulletItem("**Youth Courts** — for those aged 10–17")]),
                .subheading("Civil Courts"),
                .bulletList([BulletItem("**County Courts** — civil disputes including personal injury, family matters, contract breaches, divorce"), BulletItem("**Small claims procedure** — informal resolution for claims under £5,000 (England/Wales) or £3,000 (Scotland/N. Ireland)")]),
                .checkUnderstand(["The role of the judiciary", "The different criminal courts in the UK", "The different civil courts in the UK", "How to settle a small claim"])
            ]),
            HandbookSection(id: "c5s6", title: "Fundamental Principles & Taxation", blocks: [
                .subheading("Human Rights"),
                .paragraph("The Human Rights Act 1998 incorporated the European Convention on Human Rights into UK law. Fundamental rights include:"),
                .bulletList([BulletItem("Right to life"), BulletItem("Prohibition of torture"), BulletItem("Right to liberty and security"), BulletItem("Right to a fair trial"), BulletItem("Freedom of thought, conscience and religion"), BulletItem("Freedom of expression (speech)")]),
                .subheading("Income Tax and National Insurance"),
                .paragraph("For most employees, income tax is deducted automatically through Pay As You Earn (PAYE). Self-employed people complete a self-assessment tax return. National Insurance Contributions fund state benefits and the NHS. All those in paid work must contribute."),
                .subheading("Driving"),
                .paragraph("You must be at least 17 to drive a car, and hold a valid driving licence. Cars over 3 years old need an annual MOT test. Motor insurance is compulsory — driving without it is a serious criminal offence."),
                .checkUnderstand(["The fundamental principles of UK law", "That domestic violence, FGM and forced marriage are illegal in the UK", "The system of income tax and National Insurance", "The requirements for driving a car"])
            ]),
            HandbookSection(id: "c5s7", title: "Your Role in the Community", blocks: [
                .subheading("Shared Values and Responsibilities"),
                .bulletList([BulletItem("Obey and respect the law"), BulletItem("Respect the rights of others"), BulletItem("Treat others with fairness"), BulletItem("Behave responsibly"), BulletItem("Respect and preserve the environment"), BulletItem("Treat everyone equally regardless of background"), BulletItem("Vote in local and national elections")]),
                .subheading("Ways to Get Involved"),
                .bulletList([BulletItem("**Jury service** — anyone on the electoral register aged 18–70 can be selected"), BulletItem("**Helping in schools** — classroom support, parent-teacher associations, becoming a school governor"), BulletItem("**Volunteering** — with local hospitals, charities, police (special constable), magistracy"), BulletItem("**Blood and organ donation** — register at www.organdonation.nhs.uk")]),
                .subheading("Looking After the Environment"),
                .paragraph("Recycle as much waste as possible. Shop locally to support British businesses and reduce your carbon footprint. Use public transport where possible to reduce pollution."),
                .checkUnderstand(["How to vote and who is eligible", "The role of school governors", "Different ways to volunteer and support your community", "How to donate blood and organs", "How you can look after the environment"])
            ])
        ]
    )
}
