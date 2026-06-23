#!/usr/bin/env node
/**
 * generate_news_docx.js
 *
 * 用法：node generate_news_docx.js <input.json> <output.docx>
 *
 * input.json 格式：
 * {
 *   "date": "0509",
 *   "items": [
 *     {
 *       "headline": "新聞標題 | 來源",
 *       "comments": [
 *         "第一點摘要...",
 *         "第二點摘要...",
 *         "第三點分析..."
 *       ]
 *     }
 *   ]
 * }
 */

const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun,
  AlignmentType, LevelFormat
} = require("docx");

const inputPath = process.argv[2];
const outputPath = process.argv[3];

if (!inputPath || !outputPath) {
  console.error("Usage: node generate_news_docx.js <input.json> <output.docx>");
  process.exit(1);
}

const data = JSON.parse(fs.readFileSync(inputPath, "utf-8"));

// --- Constants ---
const FONT = "微軟正黑體";
const BLUE = "2E74B5";
const BLACK = "000000";
const LINE_SPACING = 320; // 16pt exact

// --- Shared run properties ---
const blueBoldRpr = {
  font: FONT,
  bold: true,
  color: BLUE,
  sizeComplexScript: 24,
};

const blackRpr = {
  font: FONT,
  boldComplexScript: true,
  sizeComplexScript: 24,
};

// --- Build numbering config ---
// numId 1 = headline bullets (Wingdings, blue)
// numId 2+ = each news item's commentary numbering (1),(2),(3)...
const numberingConfig = [];

// Headline bullet list
numberingConfig.push({
  reference: "headline-bullets",
  levels: [
    {
      level: 0,
      format: LevelFormat.BULLET,
      text: "§", // Wingdings bullet placeholder - will use dash-like
      alignment: AlignmentType.LEFT,
      style: {
        paragraph: {
          indent: { left: 480, hanging: 480 },
        },
        run: {
          font: "Wingdings",
          color: BLUE,
        },
      },
    },
  ],
});

// Create a separate numbering reference for each news item's commentary
const items = data.items || [];
for (let i = 0; i < items.length; i++) {
  numberingConfig.push({
    reference: `commentary-${i}`,
    levels: [
      {
        level: 0,
        format: LevelFormat.DECIMAL,
        text: "(%1)",
        alignment: AlignmentType.LEFT,
        style: {
          paragraph: {
            indent: { left: 480, hanging: 480 },
          },
          run: {
            color: BLACK,
          },
        },
      },
    ],
  });
}

// --- Build document children ---
const children = [];

// Title paragraph: 【0509評論】
const titleDate = data.date || "MMDD";
children.push(
  new Paragraph({
    spacing: { line: LINE_SPACING, lineRule: "exact" },
    alignment: AlignmentType.BOTH,
    children: [
      new TextRun({
        text: `【${titleDate}評論】`,
        ...blueBoldRpr,
      }),
    ],
  })
);

// Each news item
items.forEach((item, idx) => {
  // Empty separator paragraph between news items (not before the first one)
  if (idx > 0) {
    children.push(
      new Paragraph({
        spacing: { line: LINE_SPACING, lineRule: "exact" },
        alignment: AlignmentType.BOTH,
        children: [
          new TextRun({
            text: "",
            ...blueBoldRpr,
          }),
        ],
      })
    );
  }

  // Headline bullet
  children.push(
    new Paragraph({
      numbering: { reference: "headline-bullets", level: 0 },
      spacing: { line: LINE_SPACING, lineRule: "exact" },
      alignment: AlignmentType.BOTH,
      indent: { leftChars: 0 },
      children: [
        new TextRun({
          text: item.headline,
          ...blueBoldRpr,
        }),
      ],
    })
  );

  // "評論：" label (no empty line before it)
  children.push(
    new Paragraph({
      spacing: { line: LINE_SPACING, lineRule: "exact" },
      alignment: AlignmentType.BOTH,
      children: [
        new TextRun({
          text: "評論：",
          ...blackRpr,
        }),
      ],
    })
  );

  // Commentary points (1), (2), (3)... (no empty line before)
  const comments = item.comments || [];
  comments.forEach((comment) => {
    children.push(
      new Paragraph({
        numbering: { reference: `commentary-${idx}`, level: 0 },
        spacing: { line: LINE_SPACING, lineRule: "exact" },
        alignment: AlignmentType.BOTH,
        indent: { leftChars: 0 },
        children: [
          new TextRun({
            text: comment,
            ...blackRpr,
          }),
        ],
      })
    );
  });
});

// --- Create document ---
const doc = new Document({
  numbering: { config: numberingConfig },
  styles: {
    default: {
      document: {
        run: {
          font: FONT,
          size: 24, // 12pt
        },
      },
    },
  },
  sections: [
    {
      properties: {
        page: {
          size: {
            width: 11906,  // A4
            height: 16838,
          },
          margin: {
            top: 1440,     // 1 inch
            right: 1800,   // 1.25 inch
            bottom: 1440,
            left: 1800,
          },
        },
      },
      children: children,
    },
  ],
});

// --- Write output ---
Packer.toBuffer(doc).then((buffer) => {
  fs.writeFileSync(outputPath, buffer);
  console.log(`Generated: ${outputPath}`);
});
